import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async findOne(id: string) {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }
  async updateProfile(id: string, data: { name?: string; email?: string; profile_image?: string }) {
    return this.prisma.user.update({
      where: { id },
      data: {
        ...(data.name && { name: data.name }),
        ...(data.email && { email: data.email }),
        ...(data.profile_image && { profile_image: data.profile_image }),
      },
    });
  }
  // --- Customer cash wallet ---
  async getWallet(userId: string) {
    const user = await this.findOne(userId);
    return { balance: user.cash_wallet_balance };
  }

  // There's no real payment gateway wired to "top up" yet — this exists so
  // the Add Cash button in the app does something real (credits the ledger
  // and the wallet) rather than nothing. Swap the direct wallet increment
  // for a real M-Pesa STK-push-to-wallet flow once that's built.
  async topUpWallet(userId: string, amount: number) {
    if (amount <= 0) throw new NotFoundException('Invalid amount');
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: { cash_wallet_balance: { increment: amount } },
    });
    return { balance: user.cash_wallet_balance };
  }

  // --- Favourites ---
  async getFavorites(userId: string) {
    return this.prisma.favoriteVendor.findMany({
      where: { user_id: userId },
      include: { user: false },
    });
  }

  async addFavorite(userId: string, vendorId: string) {
    return this.prisma.favoriteVendor.upsert({
      where: { user_id_vendor_id: { user_id: userId, vendor_id: vendorId } },
      create: { user_id: userId, vendor_id: vendorId },
      update: {},
    });
  }

  async removeFavorite(userId: string, vendorId: string) {
    await this.prisma.favoriteVendor.deleteMany({ where: { user_id: userId, vendor_id: vendorId } });
    return { message: 'Removed from favourites.' };
  }

  // --- Family sharing ---
  async getFamily(ownerId: string) {
    return this.prisma.familyMember.findMany({
      where: { owner_id: ownerId },
      include: { member: true },
    });
  }

  async inviteFamilyMember(ownerId: string, memberPhone: string, spendingLimit?: number) {
    const member = await this.prisma.user.findUnique({ where: { phone: memberPhone } });
    if (!member) throw new NotFoundException('No account found with that phone number.');
    if (member.id === ownerId) throw new NotFoundException("You can't invite yourself.");

    return this.prisma.familyMember.upsert({
      where: { owner_id_member_id: { owner_id: ownerId, member_id: member.id } },
      create: { owner_id: ownerId, member_id: member.id, spending_limit: spendingLimit },
      update: { spending_limit: spendingLimit },
    });
  }

  async removeFamilyMember(ownerId: string, memberId: string) {
    await this.prisma.familyMember.deleteMany({ where: { owner_id: ownerId, member_id: memberId } });
    return { message: 'Family member removed.' };
  }

  // --- Support tickets (customer creates, Admin resolves) ---
  async createSupportTicket(userId: string, subject: string, message: string) {
    return this.prisma.supportTicket.create({
      data: { user_id: userId, subject, message },
    });
  }

  async getMySupportTickets(userId: string) {
    return this.prisma.supportTicket.findMany({
      where: { user_id: userId },
      orderBy: { created_at: 'desc' },
    });
  }
}
