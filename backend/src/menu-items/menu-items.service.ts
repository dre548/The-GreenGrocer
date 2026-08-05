import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class MenuItemsService {
  constructor(private prisma: PrismaService) {}

  async create(data: { vendor_id: string; name: string; price: number; emoji?: string; unit: string }) {
    // Fixed: vendor_id was being destructured out and discarded, so every
    // "menu item" landed in the global Product table with no owner at all.
    return this.prisma.product.create({
      data: {
        vendor_id: data.vendor_id,
        name: data.name,
        price: data.price,
        emoji: data.emoji,
        unit: data.unit,
      },
    });
  }

  async findAll() {
    return this.prisma.product.findMany({
      orderBy: { created_at: 'desc' }
    });
  }

  // Fixed: this used to ignore vendorId entirely and return the whole
  // global catalog for every vendor. Now it actually filters.
  async findByVendor(vendorId: string) {
    return this.prisma.product.findMany({
      where: { vendor_id: vendorId },
      orderBy: { created_at: 'desc' },
    });
  }

  async findOne(id: string) {
    return this.prisma.product.findUnique({ where: { id } });
  }

  async update(id: string, data: any) {
    return this.prisma.product.update({ where: { id }, data });
  }

  // Powers the "In Stock / Out of Stock" switch on the Menu Maker screen.
  async setStock(id: string, inStock: boolean) {
    return this.prisma.product.update({ where: { id }, data: { in_stock: inStock } });
  }

  async setImage(id: string, imageUrl: string) {
    return this.prisma.product.update({ where: { id }, data: { image_url: imageUrl } });
  }

  async remove(id: string) {
    return this.prisma.product.delete({ where: { id } });
  }
}
