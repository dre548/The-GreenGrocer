import { Injectable } from '@nestjs/common';
// Ensure this import path matches where your PrismaService is located
import { PrismaService } from '../prisma/prisma.service'; 

@Injectable()
export class ProductsService {
  constructor(private prisma: PrismaService) {}

  async getAllProducts() {
    return this.prisma.product.findMany({
      orderBy: {
        created_at: 'asc',
      },
    });
  }
}