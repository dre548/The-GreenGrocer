import { Controller, Get, Post, Body, Param } from '@nestjs/common';
import { VendorsService } from './vendors.service';

@Controller('vendors')
export class VendorsController {
  constructor(private readonly vendorsService: VendorsService) {}

  @Post()
  create(@Body() createVendorDto: any) {
    if (!createVendorDto.user_id || !createVendorDto.business_name) {
      return { error: 'User ID and Business Name are required.' };
    }
    return this.vendorsService.create(createVendorDto);
  }

  @Get('active')
  findAllActive() {
    return this.vendorsService.findAllActive();
  }

  @Get(':id/wallet')
  getWallet(@Param('id') id: string) {
    return this.vendorsService.getWallet(id);
  }

  @Post(':id/request-payout')
  requestPayout(@Param('id') id: string, @Body() body: { amount: number; method: string }) {
    if (!body.amount || !body.method) {
      return { error: 'Amount and method are required.' };
    }
    return this.vendorsService.requestPayout(id, body.amount, body.method);
  }
}