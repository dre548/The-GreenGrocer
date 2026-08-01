import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class VendorsService {
  constructor(private readonly prisma: PrismaService) {}
  // --- NEW: Find only vendors who have been approved by Admin ---
  async findAllActive() {
    return this.prisma.vendor.findMany({
      where: { status: 'ACTIVE' },
    });
  }

  async create(createVendorDto: any) {
    const { user_id, business_name, commission_rate, opening_hours } = createVendorDto;

    // 1. Verify the user exists
    const user = await this.prisma.user.findUnique({ where: { id: user_id } });
    if (!user) {
      throw new BadRequestException('User not found');
    }

    // 2. Upgrade the user's role to VENDOR if they aren't one already
    if (user.role !== 'VENDOR') {
      await this.prisma.user.update({
        where: { id: user_id },
        data: { role: 'VENDOR' },
      });
    }

    // 3. Create the store profile
    const vendor = await this.prisma.vendor.create({
      data: {
        user_id,
        business_name,
        commission_rate: commission_rate || 10.0, // Default 10% platform cut
        status: 'PENDING', // Requires admin approval
        opening_hours,
      },
    });

    return {
      message: 'Store created successfully. Pending admin approval.',
      vendor,
    };
  }

  async findOne(id: string) {
    return this.prisma.vendor.findUnique({
      where: { id },
      // I have removed the "include: { menu_items: true }" line here!
    });
  }

  async getWallet(vendorId: string) {
    const vendor = await this.prisma.vendor.findUnique({ where: { id: vendorId } });
    if (!vendor) throw new BadRequestException('Vendor not found');
    return { balance: vendor.wallet_balance };
  }

  // Vendor requests a payout: takes the full (or partial) balance out of
  // their live wallet immediately and logs a PENDING Transaction for Admin
  // to disburse. Mirrors the pattern the Flutter admin payout queue expects.
  async requestPayout(vendorId: string, amount: number, method: string) {
    const vendor = await this.prisma.vendor.findUnique({ where: { id: vendorId } });
    if (!vendor) throw new BadRequestException('Vendor not found');
    if (amount <= 0 || amount > vendor.wallet_balance) {
      throw new BadRequestException('Invalid payout amount');
    }

    const [, transaction] = await this.prisma.$transaction([
      this.prisma.vendor.update({
        where: { id: vendorId },
        data: { wallet_balance: { decrement: amount } },
      }),
      this.prisma.transaction.create({
        data: {
          type: 'PAYOUT',
          party: 'VENDOR',
          party_id: vendorId,
          amount,
          method,
          status: 'PENDING',
        },
      }),
    ]);

    return { message: 'Payout requested — awaiting admin disbursement.', transaction };
  }
}