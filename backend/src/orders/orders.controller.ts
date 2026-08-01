import { Controller, Post, Get, Body, UseGuards, Request } from '@nestjs/common';
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
} // <--- The Controller class safely closes here!