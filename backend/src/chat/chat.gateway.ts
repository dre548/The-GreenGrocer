import { WebSocketGateway, WebSocketServer, SubscribeMessage, MessageBody, ConnectedSocket } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { PrismaService } from '../prisma/prisma.service';

// Message Center: order-scoped real-time chat between customer, vendor,
// and rider. Clients join a room named `order_{orderId}` and every message
// is persisted to the ChatMessage table (so re-opening the chat later shows
// history — see ChatController.getHistory for the REST-side fetch).
@WebSocketGateway({ cors: { origin: '*' } })
export class ChatGateway {
  @WebSocketServer()
  server: Server;

  constructor(private readonly prisma: PrismaService) {}

  @SubscribeMessage('join_order_chat')
  handleJoin(@MessageBody() data: { orderId: string }, @ConnectedSocket() client: Socket) {
    client.join(`order_${data.orderId}`);
  }

  @SubscribeMessage('send_message')
  async handleMessage(
    @MessageBody() data: { orderId: string; senderId: string; senderRole: string; message: string },
    @ConnectedSocket() client: Socket,
  ) {
    const saved = await this.prisma.chatMessage.create({
      data: {
        order_id: data.orderId,
        sender_id: data.senderId,
        sender_role: data.senderRole,
        message: data.message,
      },
    });
    this.server.to(`order_${data.orderId}`).emit('new_message', saved);
    return saved;
  }
}
