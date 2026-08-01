import { Controller, Post, Body, Get, Query, Param, Patch } from '@nestjs/common';
import { DeliveriesService } from './deliveries.service';

@Controller('deliveries')
export class DeliveriesController {
  constructor(private readonly deliveriesService: DeliveriesService) {}

  @Get('nearby')
  findNearbyOrders(@Query('lat') lat: string, @Query('lng') lng: string) {
    if (!lat || !lng) return { error: 'GPS coordinates are required' };
    return this.deliveriesService.findNearbyOrders(parseFloat(lat), parseFloat(lng));
  }

  @Post('accept')
  acceptOrder(@Body() body: { order_id: string; rider_id: string; distance_km: number }) {
    if (!body.order_id || !body.rider_id || !body.distance_km) {
      return { error: 'Order ID, Rider ID, and Distance are required' };
    }
    return this.deliveriesService.acceptOrder(body.order_id, body.rider_id, body.distance_km);
  }

  @Patch(':id/deliver')
  markDelivered(@Param('id') id: string) {
    return this.deliveriesService.markDelivered(id);
  }
}