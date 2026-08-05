import { Controller, Get, Query } from '@nestjs/common';
import { ProductsService } from './products.service';

@Controller('products')
// 👇 CRUCIAL: It must have "export", and it must be spelled "ProductsController" (plural)
export class ProductsController { 
  constructor(private readonly productsService: ProductsService) {}

  @Get()
  async getProducts(
    @Query('page') page: string = '1',
    @Query('limit') limit: string = '20',
  ) {
    return this.productsService.getAllProducts(Number(page), Number(limit));
  }
}