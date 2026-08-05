import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ProductsService {
  constructor(private prisma: PrismaService) {}

  async getAllProducts(page: number = 1, limit: number = 20) {
    const skip = (page - 1) * limit;
    return this.prisma.product.findMany({
      skip: skip,
      take: limit,
      orderBy: { id: 'desc' }, 
    });
  }
}