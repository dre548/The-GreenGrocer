import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { PrismaService } from '../prisma/prisma.service'; 

@Module({
  imports: [
    JwtModule.register({
      global: true,
      secret: 'GREEN_GROCER_SUPER_SECRET_KEY', 
      signOptions: { expiresIn: '7d' }, 
    }),
  ],
  providers: [AuthService, PrismaService],
  controllers: [AuthController],
})
export class AuthModule {}