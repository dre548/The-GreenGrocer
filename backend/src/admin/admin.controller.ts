import { Controller, Get, Post, Param } from '@nestjs/common';
import { AdminService } from './admin.service';

@Controller('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('pending-vendors')
  async getPendingVendors() {
    return this.adminService.getPendingVendors();
  }

  @Get('pending-riders')
  async getPendingRiders() {
    return this.adminService.getPendingRiders();
  }

  @Post('approve-vendor/:id')
  async approveVendor(@Param('id') id: string) {
    await this.adminService.approveVendor(id);
    return { message: 'Vendor successfully approved and activated!' };
  }

  @Post('approve-rider/:id')
  async approveRider(@Param('id') id: string) {
    await this.adminService.approveRider(id);
    return { message: 'Rider successfully approved and activated!' };
  }

  @Get('pending-payouts')
  async getPendingPayouts() {
    return this.adminService.getPendingPayouts();
  }

  @Post('disburse-payout/:id')
  async disbursePayout(@Param('id') id: string) {
    return this.adminService.disbursePayout(id);
  }
}