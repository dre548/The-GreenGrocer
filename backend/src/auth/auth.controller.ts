import { Controller, Post, Body, UseInterceptors, UploadedFile, UploadedFiles } from '@nestjs/common';
import { AuthService } from './auth.service';
import { FileInterceptor, FileFieldsInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';

// Helper to save files with unique names
const storageOptions = diskStorage({
  destination: './uploads',
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, `${uniqueSuffix}${extname(file.originalname)}`);
  },
});

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  // 1. STANDARD LOGIN (For existing approved users)
  @Post('login')
  async login(@Body() body: { phone: string }) {
    return this.authService.generateToken(body.phone);
  }

  // 2. CUSTOMER SIGNUP
  @Post('register/customer')
  async registerCustomer(@Body() body: { phone: string, name: string }) {
    return this.authService.registerCustomer(body.phone, body.name);
  }

  // 3. VENDOR SIGNUP (Needs Admin Approval)
  @Post('register/vendor')
  async registerVendor(@Body() body: { phone: string, name: string, shopName: string, location: string }) {
    return this.authService.registerVendor(body);
  }

  // 4. RIDER SIGNUP (With ID Photo Uploads!)
  @Post('register/rider')
  @UseInterceptors(FileFieldsInterceptor([
    { name: 'idFront', maxCount: 1 },
    { name: 'idBack', maxCount: 1 },
  ], { storage: storageOptions }))
  async registerRider(
    @Body() body: { phone: string, name: string, vehicleType: string, plateNumber: string },
    @UploadedFiles() files: { idFront?: Express.Multer.File[], idBack?: Express.Multer.File[] },
  ) {
    const idFrontUrl = files.idFront ? `/uploads/${files.idFront[0].filename}` : '';
    const idBackUrl = files.idBack ? `/uploads/${files.idBack[0].filename}` : '';

    return this.authService.registerRider(body, idFrontUrl, idBackUrl);
  }
}