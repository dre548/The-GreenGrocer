import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class MenuItemsService {
  constructor(private prisma: PrismaService) {}

  async create(data: any) {
    const { vendor_id, ...productData } = data; 
    
    return this.prisma.product.create({
      data: productData,
    });
  }

  async findAll() {
    return this.prisma.product.findMany({
      orderBy: { created_at: 'desc' }
    });
  }

  // --- THE MISSING FUNCTION ADDED BACK ---
  async findByVendor(vendorId: string) {
    // We return the global catalog so the Controller stays happy
    return this.prisma.product.findMany({
      orderBy: { created_at: 'desc' }
    });
  }

  async findOne(id: string) {
    return this.prisma.product.findUnique({ where: { id } });
  }

  async update(id: string, data: any) {
    return this.prisma.product.update({ where: { id }, data });
  }

  async remove(id: string) {
    return this.prisma.product.delete({ where: { id } });
  }
}