import * as dotenv from 'dotenv';
dotenv.config();
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { PrismaService } from '../prisma/prisma.service'; 

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(
      `Missing required environment variable: ${name}. Set it in your .env file (see .env.example) — it must never be hardcoded in source.`,
    );
  }
  return value;
}

@Module({
  imports: [
    JwtModule.register({
      global: true,
      // Was hardcoded as 'GREEN_GROCER_SUPER_SECRET_KEY' in source — anyone
      // reading the public repo could forge a valid token for ANY user,
      // including ADMIN. Now read from env only; see auth.guard.ts, which
      // must use the exact same secret to verify tokens.
      secret: requireEnv('JWT_SECRET'),
      signOptions: { expiresIn: '7d' }, 
    }),
  ],
  providers: [AuthService, PrismaService],
  controllers: [AuthController],
})
export class AuthModule {}
