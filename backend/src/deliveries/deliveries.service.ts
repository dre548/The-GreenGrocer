import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { OrdersGateway } from '../orders/orders.gateway';

@Injectable()
export class DeliveriesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly gateway: OrdersGateway,
  ) {}

  // The Haversine Formula: Calculates distance between two GPS points in Kilometers
  private calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371; // Earth's radius in km
    const dLat = (lat2 - lat1) * (Math.PI / 180);
    const dLon = (lon2 - lon1) * (Math.PI / 180);
    const a = 
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * (Math.PI / 180)) * Math.cos(lat2 * (Math.PI / 180)) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c; 
  }

  // 1. Rider checks for nearby orders that are ready for a rider to grab
  // (was 'PLACED' — that's before the vendor has even accepted/prepped it;
  // riders should only see orders the vendor has marked READY_FOR_PICKUP)
  async findNearbyOrders(riderLat: number, riderLng: number, radiusKm: number = 5) {
    const availableOrders = await this.prisma.order.findMany({
      where: { status: 'READY_FOR_PICKUP', rider_id: null },
    });

    // TODO: Vendor doesn't store lat/lng yet (only a free-text `location`
    // string), so distance filtering still uses a hardcoded Nairobi CBD
    // point. Add lat/lng columns to Vendor to make this real per-store.
    const storeLat = -1.2921;
    const storeLng = 36.8219;

    const nearbyOrders = availableOrders.filter(order => {
      const distance = this.calculateDistance(riderLat, riderLng, storeLat, storeLng);
      return distance <= radiusKm;
    });

    return {
      message: `Found ${nearbyOrders.length} orders within ${radiusKm}km`,
      orders: nearbyOrders,
    };
  }

  // 2. Rider accepts a delivery — this now actually assigns rider_id and
  // moves the order to RIDER_ASSIGNED (previously there was no rider_id
  // column at all, and it incorrectly set status back to READY_FOR_PICKUP,
  // which is the vendor's state, not the rider's).
  async acceptOrder(orderId: string, riderUserId: string, distanceKm: number) {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (!order) throw new BadRequestException('Order not found');
    if (order.status !== 'READY_FOR_PICKUP') {
      throw new BadRequestException('Order is not ready for pickup, or has already been taken');
    }
    if (order.rider_id) throw new BadRequestException('Order already has a rider assigned');

    const rider = await this.prisma.rider.findUnique({ where: { user_id: riderUserId } });
    if (!rider) throw new BadRequestException('Rider profile not found for this user');
    if (rider.status !== 'ACTIVE') throw new BadRequestException('Rider is not approved yet');

    // Commission Logic: 20 KES per km + 5% of the order total
    const distancePay = distanceKm * 20;
    const percentagePay = order.total * 0.05;
    const totalCommission = distancePay + percentagePay;

    const updatedOrder = await this.prisma.order.update({
      where: { id: orderId },
      data: {
        status: 'RIDER_ASSIGNED',
        rider_id: rider.id,
      },
    });

    this.gateway.broadcastOrderStatus(orderId, 'RIDER_ASSIGNED');

    return {
      message: 'Order accepted successfully. Head to the store!',
      commission_earned: totalCommission,
      distance_km: distanceKm,
      order: updatedOrder,
    };
  }

  // 3. Rider marks pickup complete at the vendor
  async markPickedUp(orderId: string) {
    const order = await this.prisma.order.update({
      where: { id: orderId },
      data: { status: 'PICKED_UP' },
    });
    this.gateway.broadcastOrderStatus(orderId, 'PICKED_UP');
    return { message: 'Pickup confirmed. En route to customer.', order };
  }

  // 4. Rider drops off food — this now actually credits wallets via real
  // Transaction records, instead of just saying "Payment secured" with no
  // ledger entry anywhere.
  async markDelivered(orderId: string) {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (!order) throw new BadRequestException('Order not found');
    if (!order.rider_id) throw new BadRequestException('Order has no rider assigned');

    const rider = await this.prisma.rider.findUnique({ where: { id: order.rider_id } });
    const vendor = await this.prisma.vendor.findUnique({ where: { id: order.vendor_id } });
    if (!rider || !vendor) throw new BadRequestException('Rider or vendor not found');

    const distancePay = 0; // distance isn't persisted on the order yet — see note below
    const riderCommission = order.delivery_fee; // simplest model: rider keeps the delivery fee
    const platformCommissionRate = (vendor.commission_rate ?? 10) / 100;
    const vendorPayout = order.subtotal * (1 - platformCommissionRate);

    const [updatedOrder] = await this.prisma.$transaction([
      this.prisma.order.update({
        where: { id: orderId },
        data: { status: 'DELIVERED' },
      }),
      this.prisma.rider.update({
        where: { id: rider.id },
        data: { wallet_balance: { increment: riderCommission } },
      }),
      this.prisma.vendor.update({
        where: { id: vendor.id },
        data: { wallet_balance: { increment: vendorPayout } },
      }),
      this.prisma.transaction.create({
        data: {
          order_id: order.id,
          type: 'CREDIT',
          party: 'RIDER',
          party_id: rider.id,
          amount: riderCommission,
          status: 'COMPLETED',
        },
      }),
      this.prisma.transaction.create({
        data: {
          order_id: order.id,
          type: 'CREDIT',
          party: 'VENDOR',
          party_id: vendor.id,
          amount: vendorPayout,
          status: 'COMPLETED',
        },
      }),
    ]);

    this.gateway.broadcastOrderStatus(orderId, 'DELIVERED');

    return {
      message: 'Delivery complete! Wallets credited.',
      order: updatedOrder,
      rider_credited: riderCommission,
      vendor_credited: vendorPayout,
    };
  }
}
