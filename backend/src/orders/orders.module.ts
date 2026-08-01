import { Module } from '@nestjs/common';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';
import { PrismaService } from '../prisma/prisma.service';
import { OrdersGateway } from './orders.gateway'; 
import { PaymentsModule } from '../payments/payments.module'; // 1. Import the module here

@Module({
  imports: [PaymentsModule], // 2. Add it to the imports array!
  controllers: [OrdersController],
  providers: [OrdersService, PrismaService, OrdersGateway], 
  exports: [OrdersGateway], // lets DeliveriesModule reuse the same gateway/socket server
})
export class OrdersModule {}