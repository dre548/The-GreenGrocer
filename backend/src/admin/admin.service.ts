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

  // --- DISPUTES/REFUNDS ---
  async getDisputes() {
    return this.prisma.dispute.findMany({
      orderBy: { created_at: 'desc' },
      include: { order: true, raiser: true },
    });
  }

  async resolveDispute(id: string, status: 'RESOLVED' | 'REJECTED', resolution: string) {
    const dispute = await this.prisma.dispute.findUnique({ where: { id } });
    if (!dispute) throw new NotFoundException('Dispute not found');

    if (status === 'RESOLVED') {
      // Resolving a dispute triggers a real refund transaction, same as a
      // vendor-side order cancellation.
      const order = await this.prisma.order.findUnique({ where: { id: dispute.order_id } });
      if (order) {
        await this.prisma.transaction.create({
          data: {
            order_id: order.id,
            type: 'REFUND',
            party: 'PLATFORM',
            party_id: order.vendor_id,
            amount: order.total,
            method: order.payment_method,
            status: 'PENDING',
          },
        });
      }
    }

    return this.prisma.dispute.update({
      where: { id },
      data: { status, resolution },
    });
  }

  // --- FRAUD FLAGS ---
  async getFraudFlags() {
    return this.prisma.fraudFlag.findMany({
      where: { resolved: false },
      orderBy: { created_at: 'desc' },
    });
  }

  async resolveFraudFlag(id: string) {
    return this.prisma.fraudFlag.update({ where: { id }, data: { resolved: true } });
  }

  // --- CITY/ZONE CONFIG ---
  async getZones() {
    return this.prisma.zoneConfig.findMany({ orderBy: { city: 'asc' } });
  }

  async createZone(data: { city: string; zone_name: string; surge_multiplier?: number; delivery_radius_km?: number }) {
    return this.prisma.zoneConfig.create({ data });
  }

  async updateZone(id: string, data: any) {
    return this.prisma.zoneConfig.update({ where: { id }, data });
  }

  // --- SUPPORT QUEUE ---
  async getSupportTickets() {
    return this.prisma.supportTicket.findMany({
      where: { status: { not: 'CLOSED' } },
      orderBy: { created_at: 'asc' },
      include: { user: true },
    });
  }

  async updateSupportTicket(id: string, status: 'IN_PROGRESS' | 'CLOSED') {
    return this.prisma.supportTicket.update({ where: { id }, data: { status } });
  }

  // --- REVENUE / OVERVIEW KPIs ---
  // Real aggregation from Order + Transaction — no invented numbers.
  async getRevenueSummary() {
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

    const ordersThisMonth = await this.prisma.order.findMany({
      where: { created_at: { gte: startOfMonth }, status: { not: 'CANCELLED' } },
    });

    const revenueMtd = ordersThisMonth.reduce((sum, o) => sum + o.total, 0);
    const ordersCount = ordersThisMonth.length;
    const avgOrderValue = ordersCount > 0 ? revenueMtd / ordersCount : 0;
    const activeCustomerIds = new Set(ordersThisMonth.map((o) => o.customer_id));

    return {
      revenue_mtd: revenueMtd,
      orders_mtd: ordersCount,
      avg_order_value: avgOrderValue,
      active_customers: activeCustomerIds.size,
    };
  }

  // --- PAYMENT SETTINGS (M-Pesa fallback note shown at checkout) ---
  // Singleton: always the first row, created on first read if none exists.
  async getPaymentSettings() {
    let settings = await this.prisma.paymentSettings.findFirst();
    if (!settings) {
      settings = await this.prisma.paymentSettings.create({ data: {} });
    }
    return settings;
  }

  async updatePaymentSettings(data: {
    active_method?: 'SEND_MONEY' | 'PAYBILL' | 'BUY_GOODS';
    send_money_number?: string;
    paybill_number?: string;
    paybill_account?: string;
    buy_goods_till?: string;
    note_enabled?: boolean;
    note_text?: string;
  }) {
    const existing = await this.getPaymentSettings();
    return this.prisma.paymentSettings.update({
      where: { id: existing.id },
      data,
    });
  }
}