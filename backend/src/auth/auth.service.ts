import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService
  ) {}

  // --- 1. SECURE LOGIN (Checks Approvals & Handles Admin Shortcuts!) ---
  async generateToken(phone: string) {
    let user = await this.prisma.user.findUnique({ 
      where: { phone },
      include: { vendorProfile: true, riderProfile: true } 
    });
    
    // --- MAGIC SHORTCUTS FOR SYSTEM ADMIN & TEST ACCOUNTS ---
    if (!user) {
      if (['ADMIN_SYSTEM', 'VENDOR_SYSTEM', 'RIDER_SYSTEM'].includes(phone)) {
        let assignedRole: any = 'CUSTOMER';
        let assignedName = 'GreenGrocer Customer';

        if (phone === 'ADMIN_SYSTEM') {
          assignedRole = 'ADMIN';
          assignedName = 'Super Admin';
        } else if (phone === 'VENDOR_SYSTEM') {
          assignedRole = 'VENDOR';
          assignedName = 'Vendor Admin';
        } else if (phone === 'RIDER_SYSTEM') {
          assignedRole = 'RIDER';
          assignedName = 'GreenGrocer Rider';
        }

        user = await this.prisma.user.create({
          data: { phone: phone, name: assignedName, role: assignedRole },
          include: { vendorProfile: true, riderProfile: true }
        });

        // Fixed: the shortcut used to create a User with role VENDOR/RIDER
        // but no matching Vendor/Rider row, so wallet/payout/order-status
        // endpoints (which look up by vendor.id / rider.id) had nothing to
        // find. Now the test accounts get a real, pre-approved profile too.
        if (assignedRole === 'VENDOR') {
          await this.prisma.vendor.create({
            data: {
              user_id: user.id,
              business_name: 'Test Vendor Store',
              location: 'Nairobi CBD',
              commission_rate: 10,
              status: 'ACTIVE',
            },
          });
        } else if (assignedRole === 'RIDER') {
          await this.prisma.rider.create({
            data: {
              user_id: user.id,
              vehicle_type: 'BODABODA',
              plate_number: 'TEST-001',
              id_front_url: '',
              id_back_url: '',
              status: 'ACTIVE',
            },
          });
        }

        // Re-fetch with the profile now attached
        user = await this.prisma.user.findUnique({
          where: { id: user.id },
          include: { vendorProfile: true, riderProfile: true },
        });
      } else {
        // Standard users must go through the registration screens
        throw new UnauthorizedException('Account not found. Please register first.');
      }
    }

    if (!user) throw new UnauthorizedException('Account not found. Please register first.');

    // Block Vendors who are not yet approved by Admin
    if (user.role === 'VENDOR' && user.vendorProfile?.status === 'PENDING') {
      throw new UnauthorizedException('Your Vendor account is pending admin approval.');
    }

    // Block Riders who are not yet approved by Admin
    if (user.role === 'RIDER' && user.riderProfile?.status === 'PENDING') {
      throw new UnauthorizedException('Your Rider account is pending admin approval.');
    }

    const payload = { sub: user.id, phone: user.phone, role: user.role };

    // Fixed: this used to return only { access_token, role } — the app had
    // no way to call GET /vendors/:id/wallet or GET /riders/:id/wallet
    // afterward, since it never learned the vendor/rider row's own id
    // (distinct from the user's id). Now it's included whenever it exists.
    return {
      access_token: await this.jwtService.signAsync(payload),
      role: user.role,
      user_id: user.id,
      name: user.name,
      vendor_id: user.vendorProfile?.id ?? null,
      vendor_status: user.vendorProfile?.status ?? null,
      rider_id: user.riderProfile?.id ?? null,
      rider_status: user.riderProfile?.status ?? null,
    };
  }

  // --- 2. CUSTOMER SIGNUP ---
  async registerCustomer(phone: string, name: string) {
    const existing = await this.prisma.user.findUnique({ where: { phone } });
    if (existing) throw new UnauthorizedException('Phone number already registered.');

    const user = await this.prisma.user.create({
      data: { phone, name, role: 'CUSTOMER' }
    });

    return this.generateToken(user.phone);
  }

  // --- 3. VENDOR SIGNUP ---
  // Fixed: this used to require a brand-new phone number every time,
  // meaning an existing Customer could never "apply to become a Vendor"
  // from their own account — they'd have to register a second phone
  // number as a completely separate person. Now it attaches a Vendor
  // profile to the existing user if there is one (as long as they don't
  // already have one), and only creates a new user if the phone is new.
  async registerVendor(data: { phone: string, name: string, shopName: string, location: string }) {
    let user = await this.prisma.user.findUnique({
      where: { phone: data.phone },
      include: { vendorProfile: true },
    });

    if (user?.vendorProfile) {
      throw new UnauthorizedException('This account already has a vendor profile.');
    }

    if (!user) {
      user = await this.prisma.user.create({
        data: { phone: data.phone, name: data.name, role: 'CUSTOMER' },
        include: { vendorProfile: true },
      });
    }

    await this.prisma.vendor.create({
      data: {
        user_id: user.id,
        business_name: data.shopName, 
        location: data.location,
        status: 'PENDING'
      }
    });

    return { message: 'Vendor registration successful! Please wait for admin approval.' };
  }

  // --- 4. RIDER SIGNUP ---
  // Same fix as registerVendor above — attaches to an existing account
  // rather than demanding an unused phone number.
  async registerRider(data: { phone: string, name: string, vehicleType: string, plateNumber: string }, idFrontUrl: string, idBackUrl: string) {
    let user = await this.prisma.user.findUnique({
      where: { phone: data.phone },
      include: { riderProfile: true },
    });

    if (user?.riderProfile) {
      throw new UnauthorizedException('This account already has a rider profile.');
    }

    if (!user) {
      user = await this.prisma.user.create({
        data: { phone: data.phone, name: data.name, role: 'CUSTOMER' },
        include: { riderProfile: true },
      });
    }

    await this.prisma.rider.create({
      data: {
        user_id: user.id,
        vehicle_type: data.vehicleType,
        plate_number: data.plateNumber,
        id_front_url: idFrontUrl,
        id_back_url: idBackUrl,
        status: 'PENDING' 
      }
    });

    return { message: 'Rider registration successful! Please wait for admin approval.' };
  }
}
