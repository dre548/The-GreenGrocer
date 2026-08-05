import { Controller, Get, Post, Patch, Body, Param, UseGuards } from '@nestjs/common';
import { AdminService } from './admin.service';
import { AuthGuard } from '../auth/auth.guard';

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

  // --- Disputes/Refunds ---
  @UseGuards(AuthGuard)
  @Get('disputes')
  getDisputes() {
    return this.adminService.getDisputes();
  }

  @UseGuards(AuthGuard)
  @Patch('disputes/:id/resolve')
  resolveDispute(@Param('id') id: string, @Body() body: { status: 'RESOLVED' | 'REJECTED'; resolution: string }) {
    return this.adminService.resolveDispute(id, body.status, body.resolution);
  }

  // --- Fraud Flags ---
  @UseGuards(AuthGuard)
  @Get('fraud-flags')
  getFraudFlags() {
    return this.adminService.getFraudFlags();
  }

  @UseGuards(AuthGuard)
  @Patch('fraud-flags/:id/resolve')
  resolveFraudFlag(@Param('id') id: string) {
    return this.adminService.resolveFraudFlag(id);
  }

  // --- City/Zone Config ---
  @Get('zones')
  getZones() {
    return this.adminService.getZones();
  }

  @UseGuards(AuthGuard)
  @Post('zones')
  createZone(@Body() body: { city: string; zone_name: string; surge_multiplier?: number; delivery_radius_km?: number }) {
    return this.adminService.createZone(body);
  }

  @UseGuards(AuthGuard)
  @Patch('zones/:id')
  updateZone(@Param('id') id: string, @Body() body: any) {
    return this.adminService.updateZone(id, body);
  }

  // --- Support Queue ---
  @UseGuards(AuthGuard)
  @Get('support-tickets')
  getSupportTickets() {
    return this.adminService.getSupportTickets();
  }

  @UseGuards(AuthGuard)
  @Patch('support-tickets/:id')
  updateSupportTicket(@Param('id') id: string, @Body() body: { status: 'IN_PROGRESS' | 'CLOSED' }) {
    return this.adminService.updateSupportTicket(id, body.status);
  }

  // --- Revenue/Overview KPIs ---
  @UseGuards(AuthGuard)
  @Get('revenue-summary')
  getRevenueSummary() {
    return this.adminService.getRevenueSummary();
  }
}
