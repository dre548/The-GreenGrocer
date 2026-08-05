import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class PromotionsService {
  constructor(private prisma: PrismaService) {}

  async getActive() {
    return this.prisma.promotion.findMany({
      where: { active: true, OR: [{ expires_at: null }, { expires_at: { gte: new Date() } }] },
      orderBy: { created_at: 'desc' },
    });
  }

  async validateCode(code: string) {
    const promo = await this.prisma.promotion.findUnique({ where: { code } });
    if (!promo || !promo.active) throw new NotFoundException('Invalid or expired promo code.');
    if (promo.expires_at && promo.expires_at < new Date()) throw new NotFoundException('This code has expired.');
    return promo;
  }

  async create(data: { code: string; description: string; discount_pct?: number; flat_amount?: number; expires_at?: string }) {
    return this.prisma.promotion.create({
      data: { ...data, expires_at: data.expires_at ? new Date(data.expires_at) : null },
    });
  }

  async setActive(id: string, active: boolean) {
    return this.prisma.promotion.update({ where: { id }, data: { active } });
  }
}
