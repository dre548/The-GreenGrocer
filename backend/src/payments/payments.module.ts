import { Module } from '@nestjs/common';
import { PaymentsService } from './payments.service';

@Module({
  providers: [PaymentsService],
  exports: [PaymentsService], // Export it so OrdersService can trigger payments
})
export class PaymentsModule {}