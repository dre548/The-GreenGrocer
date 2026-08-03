import { Controller, Get, Post, Patch, Body, Param, UseGuards } from '@nestjs/common';
import { MenuItemsService } from './menu-items.service';
import { AuthGuard } from '../auth/auth.guard';

@Controller('menu-items')
export class MenuItemsController {
  constructor(private readonly menuItemsService: MenuItemsService) {}

  @UseGuards(AuthGuard)
  @Post()
  create(@Body() createMenuItemDto: any) {
    if (!createMenuItemDto.vendor_id || !createMenuItemDto.name || !createMenuItemDto.price) {
      return { error: 'Vendor ID, name, and price are required.' };
    }
    return this.menuItemsService.create(createMenuItemDto);
  }

  @Get('vendor/:id')
  findByVendor(@Param('id') id: string) {
    return this.menuItemsService.findByVendor(id);
  }

  @UseGuards(AuthGuard)
  @Patch(':id/stock')
  setStock(@Param('id') id: string, @Body() body: { in_stock: boolean }) {
    return this.menuItemsService.setStock(id, body.in_stock);
  }
}
