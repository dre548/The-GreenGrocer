import { Controller, Post, Get, Patch, Param, Body, UseGuards, Request } from '@nestjs/common';
import { OrdersService } from './orders.service';
import { AuthGuard } from '../auth/auth.guard';
import { OrderStatus } from '@prisma/client'; 

@Controller('orders')
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  @UseGuards(AuthGuard)
  @Post('checkout')
  async checkout(@Body() cartData: any, @Request() req: any) {
    const userPhone = req.user.phone; 
    return this.ordersService.processCheckout(cartData, userPhone);
  }

  @UseGuards(AuthGuard)
  @Get('history')
  async getHistory(@Request() req: any) {
    return this.ordersService.getOrdersByPhone(req.user.phone);
  }

  @UseGuards(AuthGuard)
  @Get('vendor-dashboard')
  async getVendorOrders(@Request() req: any) {
    return this.ordersService.getVendorOrders(req.user.sub);
  }

  @UseGuards(AuthGuard)
  @Post('update-status')
  async updateStatus(@Body() body: { orderId: string, status: OrderStatus }) {
    return this.ordersService.updateOrderStatus(body.orderId, body.status);
  }

  @UseGuards(AuthGuard)
  @Post('add-product')
  async addProduct(@Body() body: { name: string, price: number, emoji: string, unit: string }) {
    return this.ordersService.addProduct(body);
  }
  @UseGuards(AuthGuard)
  @Get('available-deliveries')
  async getAvailableDeliveries() {
    return this.ordersService.getAvailableDeliveries();
  }

  @UseGuards(AuthGuard)
  @Patch(':id/cancel')
  async cancelOrder(@Param('id') id: string, @Body() body: { reason: string }) {
    return this.ordersService.cancelOrder(id, body.reason ?? 'No reason given');
  }

  @UseGuards(AuthGuard)
  @Post(':id/rate')
  async rateOrder(@Param('id') id: string, @Body() body: { target: 'VENDOR' | 'RIDER', score: number, comment?: string }) {
    return this.ordersService.rateOrder(id, body.target, body.score, body.comment);
  }
} // <--- The Controller class safely closes here!