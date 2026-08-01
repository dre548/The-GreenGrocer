import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service'; 
import { OrderStatus } from '@prisma/client'; 
import { OrdersGateway } from './orders.gateway'; 
import { PaymentsService } from '../payments/payments.service'; // <-- Imported Payments

@Injectable()
export class OrdersService {
  constructor(
    private prisma: PrismaService,
    private gateway: OrdersGateway,
    private paymentsService: PaymentsService // <-- Injected Payments
  ) {}

  // --- FUNCTION 1: CHECKOUT (UPGRADED WITH M-PESA & IDEMPOTENCY) ---
  async processCheckout(cartData: any, phone: string) {
    const { items, subtotal, idempotencyKey } = cartData;

    // 1. Idempotency Check: Prevent double-charging if the user double-taps "Pay"
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

    // 4. Calculate Totals
    const deliveryFee = 50; 
    const total = subtotal + deliveryFee;

    // 5. Create Order
    const order = await this.prisma.order.create({
      data: {
        id: idempotencyKey || undefined, // Use the Flutter UUID if provided
        customer_id: customer.id,
        vendor_id: vendor.id,
        items: items, 
        subtotal: subtotal,
        delivery_fee: deliveryFee,
        total: total,
        payment_method: 'M-PESA', // Updated from COD!
        status: 'PLACED'
      },
    });

    // 6. Log the charge in the ledger (PENDING until the M-Pesa callback
    // confirms it — see the payments callback handler you'll need to add
    // for CALLBACK_URL to actually flip this to COMPLETED).
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

    // 7. Trigger the Daraja STK Push!
    try {
      await this.paymentsService.initiateStkPush(phone, total, order.id);
      console.log(`STK Push initiated successfully for order ${order.id}`);
    } catch (error) {
      console.error('STK Push failed to initiate:', error);
      // We don't throw an error here, so the order still saves even if Daraja is acting up
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
      where: { status: 'ACCEPTED_BY_VENDOR' }, 
      orderBy: { created_at: 'asc' },
      include: { customer: true } 
    });
  }
}