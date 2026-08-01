import { Controller, Get, Post, Body, Param } from '@nestjs/common';
import { MenuItemsService } from './menu-items.service';

@Controller('menu-items')
export class MenuItemsController {
  constructor(private readonly menuItemsService: MenuItemsService) {}

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
}