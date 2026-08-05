import { Injectable, HttpException, HttpStatus } from '@nestjs/common';
import axios from 'axios';

@Injectable()
export class LogisticsService {
  private readonly apiKey = process.env.DISTANCE_MATRIX_API_KEY;

  // Calculates exact driving distance and computes the Greengrocer delivery fee
  async calculateDeliveryFee(
    vendorLat: number,
    vendorLng: number,
    customerLat: number,
    customerLng: number
  ): Promise<{ distanceKm: number; deliveryFee: number }> {
    const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${vendorLat},${vendorLng}&destinations=${customerLat},${customerLng}&key=${this.apiKey}`;

    try {
      const response = await axios.get(url);
      const data = response.data;

      // Google returns 'OK' at the top level, and also inside the specific element
      if (data.status !== 'OK' || data.rows[0].elements[0].status !== 'OK') {
        throw new HttpException('Could not calculate a route between these locations', HttpStatus.BAD_REQUEST);
      }

      // Extract the distance in meters and convert to kilometers
      const distanceMeters = data.rows[0].elements[0].distance.value;
      const distanceKm = distanceMeters / 1000;

      // Pricing Logic: Base fee of 50 Ksh + 30 Ksh per Km
      const baseFee = 50;
      const perKmRate = 30;
      const deliveryFee = Math.round(baseFee + (distanceKm * perKmRate));

      return { distanceKm, deliveryFee };
      
    } catch (error) {
      throw new HttpException('Logistics routing failed', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }
}