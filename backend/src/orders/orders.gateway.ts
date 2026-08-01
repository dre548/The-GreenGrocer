import { WebSocketGateway, WebSocketServer, SubscribeMessage, MessageBody } from '@nestjs/websockets';
import { Server } from 'socket.io';

@WebSocketGateway({ cors: { origin: '*' } })
export class OrdersGateway {
  @WebSocketServer()
  server: Server;

  // --- TASK 3: DISPATCH ENGINE ---
  broadcastOrderStatus(orderId: string, status: string) {
    // 1. Notify the Customer that the status changed
    this.server.emit('order_status_changed', { orderId, status });
    
    // 2. DISPATCH BROADCAST: If the vendor just accepted it, push it to all Riders instantly!
    if (status === 'ACCEPTED_BY_VENDOR') {
      this.server.emit('new_delivery_available', { orderId });
    }
  }

  // --- TASK 4: LIVE GPS TRACKING ---
  @SubscribeMessage('update_location')
  handleLocationUpdate(@MessageBody() data: { orderId: string, lat: number, lng: number }) {
    // Receive GPS from Rider, and broadcast it specifically to the Customer waiting for this order
    this.server.emit(`tracking_${data.orderId}`, { lat: data.lat, lng: data.lng });
  }
}