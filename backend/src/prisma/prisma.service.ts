import { Injectable, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { Pool } from 'pg';
import { PrismaPg } from '@prisma/adapter-pg';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  constructor() {
    // 1. Define the connection string
    const connectionString = process.env.DATABASE_URL || "postgresql://admin:secretpassword@localhost:5432/greengrocer_db?schema=public";
    
    // 2. Create a standard Postgres connection pool
    const pool = new Pool({ connectionString });
    
    // 3. Wrap it in the Prisma adapter
    const adapter = new PrismaPg(pool);
    
    // 4. Pass the adapter to the PrismaClient
    super({ adapter });
  }

  async onModuleInit() {
    await this.$connect();
  }
}