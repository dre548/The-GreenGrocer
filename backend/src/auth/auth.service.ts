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
      } else {
        // Standard users must go through the registration screens
        throw new UnauthorizedException('Account not found. Please register first.');
      }
    }

    // Block Vendors who are not yet approved by Admin
    if (user.role === 'VENDOR' && user.vendorProfile?.status === 'PENDING') {
      throw new UnauthorizedException('Your Vendor account is pending admin approval.');
    }

    // Block Riders who are not yet approved by Admin
    if (user.role === 'RIDER' && user.riderProfile?.status === 'PENDING') {
      throw new UnauthorizedException('Your Rider account is pending admin approval.');
    }

    const payload = { sub: user.id, phone: user.phone, role: user.role };
    
    return {
      access_token: await this.jwtService.signAsync(payload),
      role: user.role,
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
  async registerVendor(data: { phone: string, name: string, shopName: string, location: string }) {
    const existing = await this.prisma.user.findUnique({ where: { phone: data.phone } });
    if (existing) throw new UnauthorizedException('Phone number already registered.');

    const user = await this.prisma.user.create({
      data: { phone: data.phone, name: data.name, role: 'VENDOR' }
    });

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
  async registerRider(data: { phone: string, name: string, vehicleType: string, plateNumber: string }, idFrontUrl: string, idBackUrl: string) {
    const existing = await this.prisma.user.findUnique({ where: { phone: data.phone } });
    if (existing) throw new UnauthorizedException('Phone number already registered.');

    const user = await this.prisma.user.create({
      data: { phone: data.phone, name: data.name, role: 'RIDER' }
    });

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