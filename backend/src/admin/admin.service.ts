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
}