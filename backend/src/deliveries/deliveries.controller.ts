import { Controller, Post, Body, Get, Query, Param, Patch, UseGuards, Request } from '@nestjs/common';
import { DeliveriesService } from './deliveries.service';
import { AuthGuard } from '../auth/auth.guard';

@Controller('deliveries')
export class DeliveriesController {
  constructor(private readonly deliveriesService: DeliveriesService) {}

  @Get('nearby')
  findNearbyOrders(@Query('lat') lat: string, @Query('lng') lng: string) {
    if (!lat || !lng) return { error: 'GPS coordinates are required' };
    return this.deliveriesService.findNearbyOrders(parseFloat(lat), parseFloat(lng));
  }

  // Was un-authenticated and took rider_id straight from the request body
  // (anyone could assign any order to any rider id). Now requires a valid
  // rider JWT, and the rider is resolved from the authenticated user.
  @UseGuards(AuthGuard)
  @Post('accept')
  acceptOrder(@Body() body: { order_id: string; distance_km: number }, @Request() req: any) {
    if (!body.order_id || body.distance_km == null) {
      return { error: 'Order ID and distance are required' };
    }
    return this.deliveriesService.acceptOrder(body.order_id, req.user.sub, body.distance_km);
  }

  @UseGuards(AuthGuard)
  @Patch(':id/picked-up')
  markPickedUp(@Param('id') id: string) {
    return this.deliveriesService.markPickedUp(id);
  }

  @UseGuards(AuthGuard)
  @Patch(':id/deliver')
  markDelivered(@Param('id') id: string) {
    return this.deliveriesService.markDelivered(id);
  }
}
