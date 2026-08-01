import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class DeliveriesService {
  constructor(private readonly prisma: PrismaService) {}

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

  // 1. Rider checks for nearby orders
  async findNearbyOrders(riderLat: number, riderLng: number, radiusKm: number = 5) {
    // Fetch all unassigned orders
    const availableOrders = await this.prisma.order.findMany({
      where: { status: 'PLACED' },
    });

    // Filter orders based on distance (Assuming store locations are hardcoded for this MVP test)
    // In production, you would pull the store's exact Lat/Lng from the Vendor table
    const storeLat = -1.2921; // Example: Nairobi CBD
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

  // 2. Rider accepts order (Calculates Commission and changes status)
  async acceptOrder(orderId: string, riderId: string, distanceKm: number) {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (!order) throw new BadRequestException('Order not found');
    if (order.status !== 'PLACED') throw new BadRequestException('Order is already taken');

    // Commission Logic: 20 KES per km + 5% of the order total
    const distancePay = distanceKm * 20;
    const percentagePay = order.total * 0.05;
    const totalCommission = distancePay + percentagePay;

    // Upgrade the user to RIDER role if they aren't one (similar to Vendor upgrade)
    await this.prisma.user.update({
      where: { id: riderId },
      data: { role: 'RIDER' },
    });

    // Update the order status to EN_ROUTE
    const updatedOrder = await this.prisma.order.update({
      where: { id: orderId },
      data: { 
        status: 'READY_FOR_PICKUP',
        // Note: If your schema doesn't have a rider_id field yet, we rely on the JSON response for now.
        // In a future Prisma migration, we would add rider_id and commission to the Order model.
      },
    });

    return {
      message: 'Order accepted successfully. Head to the store!',
      commission_earned: totalCommission,
      distance_km: distanceKm,
      order: updatedOrder,
    };
  }

  // 3. Rider drops off food and collects payment
  async markDelivered(orderId: string) {
    const order = await this.prisma.order.update({
      where: { id: orderId },
      data: { status: 'DELIVERED' },
    });

    return {
      message: 'Delivery complete! Payment secured.',
      order,
    };
  }
}