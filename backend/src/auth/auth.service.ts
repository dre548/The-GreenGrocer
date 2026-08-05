import { Injectable, HttpException, HttpStatus, Inject, UnauthorizedException } from '@nestjs/common';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import type { Cache } from 'cache-manager';
import axios from 'axios';
import { PrismaService } from '../prisma/prisma.service';
import { JwtService } from '@nestjs/jwt';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    @Inject(CACHE_MANAGER) private cacheManager: Cache,
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

        user = await this.prisma.user.findUnique({
          where: { id: user.id },
          include: { vendorProfile: true, riderProfile: true },
        });
      } else {
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

  // --- 5. AFRICA'S TALKING OTP INTEGRATION ---
  async requestOtp(phone: string) {
    const otp = Math.floor(1000 + Math.random() * 9000).toString();
    await this.cacheManager.set(`otp_${phone}`, otp, 300000);

    try {
      const params = new URLSearchParams();
      params.append('username', process.env.AT_USERNAME || 'sandbox');
      params.append('to', phone);
      params.append('message', `Your Greengrocer verification code is ${otp}. It expires in 5 minutes.`);

      const response = await axios.post(
        'https://api.africastalking.com/version1/messaging',
        params,
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            apikey: process.env.AT_API_KEY,
            Accept: 'application/json',
          },
        }
      );
      
      console.log('AT SMS Response:', response.data);
      return { success: true, message: 'OTP sent successfully' };
    } catch (error: any) {
      console.error('AT SMS Error Details:', error.response?.data || error.message);
      throw new HttpException(
        error.response?.data?.SMSMessageData?.Message || 'Failed to send SMS', 
        HttpStatus.INTERNAL_SERVER_ERROR
      );
    }
  }

  async verifyOtp(phone: string, code: string) {
    const cachedOtp = await this.cacheManager.get(`otp_${phone}`);

    if (!cachedOtp || cachedOtp !== code) {
      throw new HttpException('Invalid or expired OTP', HttpStatus.UNAUTHORIZED);
    }

    await this.cacheManager.del(`otp_${phone}`);
    return this.generateToken(phone);
  }
}