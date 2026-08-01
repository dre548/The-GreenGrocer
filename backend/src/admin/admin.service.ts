import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AdminService {
  constructor(private prisma: PrismaService) {}

  // --- FETCH PENDING APPLICATIONS ---
  async getPendingVendors() {
    return this.prisma.vendor.findMany({
      where: { status: 'PENDING' },
      include: { user: true }, 
    });
  }

  async getPendingRiders() {
    return this.prisma.rider.findMany({
      where: { status: 'PENDING' },
      include: { user: true }, 
    });
  }

  // --- APPROVAL LOGIC ---
  async approveVendor(vendorId: string) {
    const vendor = await this.prisma.vendor.findUnique({ where: { id: vendorId } });
    if (!vendor) throw new NotFoundException('Vendor not found');

    return this.prisma.vendor.update({
      where: { id: vendorId },
      data: { status: 'ACTIVE' },
    });
  }

  async approveRider(riderId: string) {
    const rider = await this.prisma.rider.findUnique({ where: { id: riderId } });
    if (!rider) throw new NotFoundException('Rider not found');

    return this.prisma.rider.update({
      where: { id: riderId },
      data: { status: 'ACTIVE' },
    });
  }

  // --- PAYOUT QUEUE (backs the Admin "Payout Dashboard" tab) ---
  async getPendingPayouts() {
    return this.prisma.transaction.findMany({
      where: { type: 'PAYOUT', status: 'PENDING' },
      orderBy: { created_at: 'asc' },
    });
  }

  async disbursePayout(transactionId: string) {
    const transaction = await this.prisma.transaction.findUnique({ where: { id: transactionId } });
    if (!transaction) throw new NotFoundException('Transaction not found');
    if (transaction.type !== 'PAYOUT') throw new NotFoundException('Not a payout transaction');

    // NOTE: this marks the payout as disbursed in the ledger. Actually
    // sending the money (M-Pesa B2C to the vendor/rider's phone) is a
    // separate step — see PaymentsService.initiateB2CPayout, which needs
    // MPESA_INITIATOR_NAME / MPESA_SECURITY_CREDENTIAL configured first.
    return this.prisma.transaction.update({
      where: { id: transactionId },
      data: { status: 'COMPLETED' },
    });
  }
}