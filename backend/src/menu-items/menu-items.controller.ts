import { Controller, Get, Post, Patch, Body, Param, UseGuards, UseInterceptors, UploadedFile } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
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

  // Vendor Product Images: accepts a single multipart image, saves it to
  // /uploads (already served statically — see main.ts), and stores the
  // public URL on the product's image_url column.
  @UseGuards(AuthGuard)
  @Post(':id/image')
  @UseInterceptors(FileInterceptor('image', {
    storage: diskStorage({
      destination: './uploads',
      filename: (req, file, cb) => {
        const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
        cb(null, `product-${uniqueSuffix}${extname(file.originalname)}`);
      },
    }),
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  }))
  async uploadImage(@Param('id') id: string, @UploadedFile() file: Express.Multer.File) {
    if (!file) return { error: 'No image file uploaded.' };
    // NOTE: replace with your real deployed host/domain in production —
    // this assumes the API is reachable at the same origin the app already
    // uses for every other request (see API_BASE_URL in the Flutter .env).
    const imageUrl = `/uploads/${file.filename}`;
    return this.menuItemsService.setImage(id, imageUrl);
  }
}
