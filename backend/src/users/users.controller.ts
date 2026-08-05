import { Controller, Get, Post, Delete, Body, Param, UseGuards } from '@nestjs/common';
import { UsersService } from './users.service';
import { AuthGuard } from '../auth/auth.guard';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @UseGuards(AuthGuard)
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.usersService.findOne(id);
  }

  // --- Wallet ---
  @UseGuards(AuthGuard)
  @Get(':id/wallet')
  getWallet(@Param('id') id: string) {
    return this.usersService.getWallet(id);
  }

  @UseGuards(AuthGuard)
  @Post(':id/wallet/top-up')
  topUpWallet(@Param('id') id: string, @Body() body: { amount: number }) {
    return this.usersService.topUpWallet(id, body.amount);
  }

  // --- Favourites ---
  @UseGuards(AuthGuard)
  @Get(':id/favorites')
  getFavorites(@Param('id') id: string) {
    return this.usersService.getFavorites(id);
  }

  @UseGuards(AuthGuard)
  @Post(':id/favorites')
  addFavorite(@Param('id') id: string, @Body() body: { vendor_id: string }) {
    return this.usersService.addFavorite(id, body.vendor_id);
  }

  @UseGuards(AuthGuard)
  @Delete(':id/favorites/:vendorId')
  removeFavorite(@Param('id') id: string, @Param('vendorId') vendorId: string) {
    return this.usersService.removeFavorite(id, vendorId);
  }

  // --- Family ---
  @UseGuards(AuthGuard)
  @Get(':id/family')
  getFamily(@Param('id') id: string) {
    return this.usersService.getFamily(id);
  }

  @UseGuards(AuthGuard)
  @Post(':id/family')
  inviteFamilyMember(@Param('id') id: string, @Body() body: { phone: string; spending_limit?: number }) {
    return this.usersService.inviteFamilyMember(id, body.phone, body.spending_limit);
  }

  @UseGuards(AuthGuard)
  @Delete(':id/family/:memberId')
  removeFamilyMember(@Param('id') id: string, @Param('memberId') memberId: string) {
    return this.usersService.removeFamilyMember(id, memberId);
  }

  // --- Support tickets ---
  @UseGuards(AuthGuard)
  @Post(':id/support-tickets')
  createSupportTicket(@Param('id') id: string, @Body() body: { subject: string; message: string }) {
    return this.usersService.createSupportTicket(id, body.subject, body.message);
  }

  @UseGuards(AuthGuard)
  @Get(':id/support-tickets')
  getMySupportTickets(@Param('id') id: string) {
    return this.usersService.getMySupportTickets(id);
  }
}
