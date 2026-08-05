import { Controller, Get, Post, Patch, Body, Param, UseGuards } from '@nestjs/common';
import { PromotionsService } from './promotions.service';
import { AuthGuard } from '../auth/auth.guard';

@Controller('promotions')
export class PromotionsController {
  constructor(private readonly promotionsService: PromotionsService) {}

  @Get()
  getActive() {
    return this.promotionsService.getActive();
  }

  @Get('validate/:code')
  validateCode(@Param('code') code: string) {
    return this.promotionsService.validateCode(code);
  }

  @UseGuards(AuthGuard)
  @Post()
  create(@Body() body: any) {
    return this.promotionsService.create(body);
  }

  @UseGuards(AuthGuard)
  @Patch(':id/active')
  setActive(@Param('id') id: string, @Body() body: { active: boolean }) {
    return this.promotionsService.setActive(id, body.active);
  }
}
