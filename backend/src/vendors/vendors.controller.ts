import { Controller, Get, Post, Body } from '@nestjs/common';
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
}