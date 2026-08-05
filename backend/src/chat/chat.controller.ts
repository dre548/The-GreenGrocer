import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuthGuard } from '../auth/auth.guard';

@Controller('chat')
export class ChatController {
  constructor(private readonly prisma: PrismaService) {}

  // REST fallback for loading history when the chat screen first opens
  // (the gateway above only pushes new messages to already-connected sockets).
  @UseGuards(AuthGuard)
  @Get(':orderId/history')
  async getHistory(@Param('orderId') orderId: string) {
    return this.prisma.chatMessage.findMany({
      where: { order_id: orderId },
      orderBy: { created_at: 'asc' },
    });
  }
}
