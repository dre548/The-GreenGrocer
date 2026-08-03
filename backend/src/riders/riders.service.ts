import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class RidersService {
  constructor(private readonly prisma: PrismaService) {}

  async getWallet(riderId: string) {
    const rider = await this.prisma.rider.findUnique({ where: { id: riderId } });
    if (!rider) throw new BadRequestException('Rider not found');
    return { balance: rider.wallet_balance };
  }

  // Same pattern as VendorsService.requestPayout: takes the balance out of
  // the wallet immediately and logs a PENDING Transaction for Admin.
  async requestPayout(riderId: string, amount: number, method: string) {
    const rider = await this.prisma.rider.findUnique({ where: { id: riderId } });
    if (!rider) throw new BadRequestException('Rider not found');
    if (amount <= 0 || amount > rider.wallet_balance) {
      throw new BadRequestException('Invalid payout amount');
    }

    const [, transaction] = await this.prisma.$transaction([
      this.prisma.rider.update({
        where: { id: riderId },
        data: { wallet_balance: { decrement: amount } },
      }),
      this.prisma.transaction.create({
        data: {
          type: 'PAYOUT',
          party: 'RIDER',
          party_id: riderId,
          amount,
          method,
          status: 'PENDING',
        },
      }),
    ]);

    return { message: 'Payout requested — awaiting admin disbursement.', transaction };
  }

  // Powers the rider-side "ratings" view (reused for feedback reporting).
  async getRatings(riderId: string) {
    const ratings = await this.prisma.rating.findMany({
      where: { target: 'RIDER', target_id: riderId },
      orderBy: { created_at: 'desc' },
    });
    const average = ratings.length
      ? ratings.reduce((sum, r) => sum + r.score, 0) / ratings.length
      : 0;
    return { average, count: ratings.length, ratings };
  }
}
