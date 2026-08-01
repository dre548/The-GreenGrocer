import { Module } from '@nestjs/common';
import { DeliveriesService } from './deliveries.service';
import { DeliveriesController } from './deliveries.controller';
import { OrdersModule } from '../orders/orders.module';

@Module({
  imports: [OrdersModule], // for the shared OrdersGateway (real-time broadcasts)
  controllers: [DeliveriesController],
  providers: [DeliveriesService],
})
export class DeliveriesModule {}
