import { Controller, Get, Post, Body, Param } from '@nestjs/common';
import { RidersService } from './riders.service';

@Controller('riders')
export class RidersController {
  constructor(private readonly ridersService: RidersService) {}

  @Get(':id/wallet')
  getWallet(@Param('id') id: string) {
    return this.ridersService.getWallet(id);
  }

  @Post(':id/request-payout')
  requestPayout(@Param('id') id: string, @Body() body: { amount: number; method: string }) {
    if (!body.amount || !body.method) {
      return { error: 'Amount and method are required.' };
    }
    return this.ridersService.requestPayout(id, body.amount, body.method);
  }

  @Get(':id/ratings')
  getRatings(@Param('id') id: string) {
    return this.ridersService.getRatings(id);
  }
}
