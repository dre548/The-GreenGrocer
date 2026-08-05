import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service'; 
import { OrderStatus } from '@prisma/client'; 
import { OrdersGateway } from './orders.gateway'; 
import { PaymentsService } from '../payments/payments.service';
import { LogisticsService } from './logistics.service'; // <-- Imported Logistics

@Injectable()
export class OrdersService {
  constructor(
    private prisma: PrismaService,
    private gateway: OrdersGateway,
    private paymentsService: PaymentsService, // <-- Added missing comma!
    private logistics: LogisticsService
  ) {}

  // --- FUNCTION 1: CHECKOUT (UPGRADED WITH DYNAMIC LOGISTICS) ---
  async processCheckout(cartData: any, phone: string) {
    // Extract coordinates if the frontend sends them
    const { items, subtotal, idempotencyKey, customerLat, customerLng, vendorLat, vendorLng } = cartData;

    // 1. Idempotency Check: Prevent double-charging
    if (idempotencyKey) {
      const existingOrder = await this.prisma.order.findUnique({
        where: { id: idempotencyKey }
      });
      if (existingOrder) {
        return { success: true, orderId: existingOrder.id, message: 'Order is already processing.' };
      }
    }

    // 2. Resolve Customer
    let customer = await this.prisma.user.findUnique({ where: { phone } });
    if (!customer) {
      customer = await this.prisma.user.create({
        data: { phone, name: 'GreenGrocer Customer', role: 'CUSTOMER' },
      });
    }

    // 3. Resolve Vendor (Default fallback for now)
    let vendor = await this.prisma.vendor.findFirst();
    if (!vendor) {
      const vendorUser = await this.prisma.user.create({
        data: { phone: 'VENDOR_SYSTEM', name: 'Vendor Admin', role: 'VENDOR' }
      });
      vendor = await this.prisma.vendor.create({
        data: { user_id: vendorUser.id, business_name: 'The GreenGrocer Official', commission_rate: 10.0, status: 'ACTIVE' }
      });
    }

    // 4. Calculate Totals (DYNAMIC LOGISTICS)
    let deliveryFee = 50; // Base flat-fee fallback
    
    // If the frontend provided coordinates, calculate the exact driving fee
    if (customerLat && customerLng && vendorLat && vendorLng) {
      try {
        const routing = await this.logistics.calculateDeliveryFee(
          vendorLat, vendorLng, 
          customerLat, customerLng
        );
        deliveryFee = routing.deliveryFee;
      } catch (error) {
        console.error('Logistics fee calculation failed, using base fee:', error);
      }
    }

    const total = subtotal + deliveryFee;

    // 5. Create Order
    const order = await this.prisma.order.create({
      data: {
        id: idempotencyKey || undefined,
        customer_id: customer.id,
        vendor_id: vendor.id,
        items: items, 
        subtotal: subtotal,
        delivery_fee: deliveryFee,
        total: total,
        payment_method: 'M-PESA',
        status: 'PLACED'
      },
    });

    // 6. Log the charge in the ledger
    await this.prisma.transaction.create({
      data: {
        order_id: order.id,
        type: 'CHARGE',
        party: 'PLATFORM',
        party_id: vendor.id,
        amount: total,
        method: 'M-PESA',
        status: 'PENDING',
      },
    });

    // 7. Trigger the Daraja STK Push
    try {
      await this.paymentsService.initiateStkPush(phone, total, order.id);
      console.log(`STK Push initiated successfully for order ${order.id}`);
    } catch (error) {
      console.error('STK Push failed to initiate:', error);
    }

    return { success: true, orderId: order.id, message: 'STK Push sent to your phone!' };
  } 

  // --- FUNCTION 2: ORDER HISTORY ---
  async getOrdersByPhone(phone: string) {
    const customer = await this.prisma.user.findUnique({ where: { phone } });
    if (!customer) return []; 
    return this.prisma.order.findMany({
      where: { customer_id: customer.id },
      orderBy: { created_at: 'desc' },
    });
  }

  // --- FUNCTION 3: VENDOR DASHBOARD ---
  async getVendorOrders(userId: string) {
    const vendor = await this.prisma.vendor.findUnique({ where: { user_id: userId } });
    if (!vendor) return [];
    return this.prisma.order.findMany({
      where: { vendor_id: vendor.id },
      orderBy: { created_at: 'desc' },
      include: { customer: true } 
    });
  }

  // --- FUNCTION 4: UPDATE ORDER STATUS ---
  async updateOrderStatus(orderId: string, newStatus: OrderStatus) {
    const updatedOrder = await this.prisma.order.update({
      where: { id: orderId },
      data: { status: newStatus },
    });

    // Instantly broadcast the change!
    this.gateway.broadcastOrderStatus(orderId, newStatus);

    return updatedOrder;
  }

  // --- FUNCTION 5: VENDOR ADD PRODUCT ---
  async addProduct(productData: { name: string, price: number, emoji: string, unit: string }) {
    return this.prisma.product.create({
      data: {
        name: productData.name,
        price: productData.price,
        emoji: productData.emoji,
        unit: productData.unit,
      }
    });
  }

  // --- FUNCTION 6: GET AVAILABLE DELIVERIES (RIDER) ---
  async getAvailableDeliveries() {
    return this.prisma.order.findMany({
      where: { status: 'READY_FOR_PICKUP', rider_id: null },
      orderBy: { created_at: 'asc' },
      include: { customer: true } 
    });
  }

  // --- FUNCTION 7: CANCEL ORDER (vendor "Manage Order" -> Cancel) ---
  async cancelOrder(orderId: string, reason: string) {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (!order) throw new Error('Order not found');

    const [updatedOrder] = await this.prisma.$transaction([
      this.prisma.order.update({
        where: { id: orderId },
        data: { status: 'CANCELLED' },
      }),
      this.prisma.transaction.create({
        data: {
          order_id: orderId,
          type: 'REFUND',
          party: 'PLATFORM',
          party_id: order.vendor_id,
          amount: order.total,
          method: order.payment_method,
          status: 'PENDING', 
        },
      }),
    ]);

    this.gateway.broadcastOrderStatus(orderId, 'CANCELLED');
    return { message: `Order cancelled: ${reason}`, order: updatedOrder };
  }

  // --- FUNCTION 8: RATE ORDER (customer rates vendor or rider after delivery) ---
  async rateOrder(orderId: string, target: 'VENDOR' | 'RIDER', score: number, comment?: string) {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (!order) throw new Error('Order not found');
    if (order.status !== 'DELIVERED') throw new Error('Can only rate a delivered order');

    const targetId = target === 'VENDOR' ? order.vendor_id : order.rider_id;
    if (!targetId) throw new Error(`Order has no ${target.toLowerCase()} to rate`);

    return this.prisma.rating.create({
      data: { order_id: orderId, target, target_id: targetId, score, comment },
    });
  }

  // --- FUNCTION 9: RAISE DISPUTE (customer -> feeds Admin's Disputes tab) ---
  async raiseDispute(orderId: string, raisedBy: string, reason: string) {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (!order) throw new Error('Order not found');
    return this.prisma.dispute.create({
      data: { order_id: orderId, raised_by: raisedBy, reason },
    });
  }
}