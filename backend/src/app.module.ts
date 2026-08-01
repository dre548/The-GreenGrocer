import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './prisma/prisma.module';
import { UsersModule } from './users/users.module';
import { AuthModule } from './auth/auth.module';
import { CacheModule } from '@nestjs/cache-manager';
import { redisStore } from 'cache-manager-redis-yet';
import { VendorsModule } from './vendors/vendors.module';
import { MenuItemsModule } from './menu-items/menu-items.module';
import { OrdersModule } from './orders/orders.module';
import { DeliveriesModule } from './deliveries/deliveries.module';
import { ProductsModule } from './products/products.module';
import { AdminModule } from './admin/admin.module';
import { RidersModule } from './riders/riders.module';

@Module({
  imports: [
    PrismaModule,
    UsersModule,
    AuthModule,
    AdminModule,
    // This connects your app to the Docker Redis instance
    CacheModule.registerAsync({
      isGlobal: true, // Makes the cache available everywhere
      useFactory: async () => ({
        store: await redisStore({
          url: process.env.REDIS_URL || 'redis://localhost:6379',
        }),
      }),
    }),
    VendorsModule,
    MenuItemsModule,
    OrdersModule,
    DeliveriesModule,
    ProductsModule,
    RidersModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}