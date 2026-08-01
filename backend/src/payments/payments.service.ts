import { Injectable, InternalServerErrorException } from '@nestjs/common';
import axios from 'axios';

@Injectable()
export class PaymentsService {
  // Use Sandbox URLs for testing. Switch to production URLs later.
  private consumerKey = process.env.MPESA_CONSUMER_KEY || 'UTRVOVmAxyEMyDbm7jHOCoHxTyRMxy7TR30IMtoNo6AENI3r';
  private consumerSecret = process.env.MPESA_CONSUMER_SECRET || '2prgEnGTeJk9nsKArPuBn5Sl7qGU4HZUK3zyoDhub5qdKQVxYUw5artgcgtEzdgV';
  private passkey = process.env.MPESA_PASSKEY || 'bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919';
  private shortcode = process.env.MPESA_SHORTCODE || '174379';
  
  // Your ngrok or production domain to receive M-Pesa callbacks
  private callbackUrl = process.env.CALLBACK_URL || 'https://unsorted-batboy-confront.ngrok-free.de.ngrok.io/payments/callback';

  async getAccessToken(): Promise<string> {
    const credentials = Buffer.from(`${this.consumerKey}:${this.consumerSecret}`).toString('base64');
    try {
      const response = await axios.get(
        'https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials',
        { headers: { Authorization: `Basic ${credentials}` } }
      );
      return response.data.access_token;
    } catch (error) {
      throw new InternalServerErrorException('Failed to get M-Pesa access token');
    }
  }

  async initiateStkPush(phone: string, amount: number, orderRef: string) {
    const token = await this.getAccessToken();
    
    // Format phone to 254...
    let formattedPhone = phone;
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '254' + formattedPhone.substring(1);
    } else if (formattedPhone.startsWith('+')) {
      formattedPhone = formattedPhone.substring(1);
    }

    const timestamp = new Date().toISOString().replace(/[^0-9]/g, '').slice(0, -3);
    const password = Buffer.from(`${this.shortcode}${this.passkey}${timestamp}`).toString('base64');

    const payload = {
      BusinessShortCode: this.shortcode,
      Password: password,
      Timestamp: timestamp,
      TransactionType: 'CustomerPayBillOnline',
      Amount: Math.round(amount),
      PartyA: formattedPhone,
      PartyB: this.shortcode,
      PhoneNumber: formattedPhone,
      CallBackURL: this.callbackUrl,
      AccountReference: orderRef.substring(0, 12), // Max 12 chars
      TransactionDesc: 'GreenGrocer Order'
    };

    try {
      const response = await axios.post(
        'https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest',
        payload,
        { headers: { Authorization: `Bearer ${token}` } }
      );
      return response.data;
    } catch (error) {
      throw new InternalServerErrorException('M-Pesa STK Push failed to initiate');
    }
  }
}