import { Injectable, HttpException, HttpStatus } from '@nestjs/common';
import axios from 'axios';

@Injectable()
export class LogisticsService {
  private apiKey = process.env.DISTANCE_MATRIX_API_KEY;

  async calculateDistanceAndFee(
    vendorLat: number,
    vendorLng: number,
    customerLat: number,
    customerLng: number
  ): Promise<{ distanceKm: number; deliveryFee: number }> {
    if (!this.apiKey) {
      throw new HttpException(
        'Distance Matrix is not configured on the server: set DISTANCE_MATRIX_API_KEY in the backend .env.',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }

    const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${vendorLat},${vendorLng}&destinations=${customerLat},${customerLng}&key=${this.apiKey}`;

    let data: any;
    try {
      const response = await axios.get(url);
      data = response.data;
    } catch (error) {
      // Fixed: this used to catch BOTH network failures AND the
      // deliberate "no route found" throw below, and mash them into the
      // same generic 500 "Logistics routing failed" — so the 400 a few
      // lines down never actually reached the caller as a 400. Network/
      // request failures are now the only thing caught here.
      throw new HttpException('Logistics routing request failed', HttpStatus.INTERNAL_SERVER_ERROR);
    }

    // Google returns 'OK' at the top level, and also inside the specific element
    if (data.status !== 'OK' || data.rows?.[0]?.elements?.[0]?.status !== 'OK') {
      throw new HttpException(
        `Could not calculate a route between these locations (Google status: ${data.status}).`,
        HttpStatus.BAD_REQUEST,
      );
    }

    const distanceMeters = data.rows[0].elements[0].distance.value;
    const distanceKm = distanceMeters / 1000;

    // Pricing Logic: Base fee of 50 Ksh + 30 Ksh per Km
    const baseFee = 50;
    const perKmRate = 30;
    const deliveryFee = Math.round(baseFee + (distanceKm * perKmRate));

    return { distanceKm, deliveryFee };
  }
}