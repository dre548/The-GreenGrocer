import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Global() // Makes Prisma available everywhere without importing the module constantly
@Module({
  providers: [PrismaService],
  exports: [PrismaService], 
})
export class PrismaModule {}