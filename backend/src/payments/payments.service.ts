import { Injectable, InternalServerErrorException } from '@nestjs/common';
import axios from 'axios';

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(
      `Missing required environment variable: ${name}. Set it in your .env file (see .env.example) — it must never be hardcoded in source.`,
    );
  }
  return value;
}

@Injectable()
export class PaymentsService {
  // These are read from environment variables only. There is no hardcoded
  // fallback — if a variable is missing, the app fails fast at startup
  // instead of silently running with a secret baked into source control.
  private consumerKey = requireEnv('MPESA_CONSUMER_KEY');
  private consumerSecret = requireEnv('MPESA_CONSUMER_SECRET');
  private passkey = requireEnv('MPESA_PASSKEY');
  private shortcode = requireEnv('MPESA_SHORTCODE');
  private callbackUrl = requireEnv('CALLBACK_URL');

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

  // --- B2C PAYOUT (vendor/rider withdrawals) ---
  // NOTE: this calls the Daraja B2C endpoint, which requires additional
  // credentials (initiator name + security credential) beyond STK push.
  // Wire the two extra env vars below once you have B2C sandbox/production
  // access from Safaricom, then this is ready to be called from the
  // payout-disbursement flow.
  async initiateB2CPayout(phone: string, amount: number, remarks: string) {
    const token = await this.getAccessToken();
    const initiatorName = requireEnv('MPESA_INITIATOR_NAME');
    const securityCredential = requireEnv('MPESA_SECURITY_CREDENTIAL');

    let formattedPhone = phone;
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '254' + formattedPhone.substring(1);
    } else if (formattedPhone.startsWith('+')) {
      formattedPhone = formattedPhone.substring(1);
    }

    const payload = {
      InitiatorName: initiatorName,
      SecurityCredential: securityCredential,
      CommandID: 'BusinessPayment',
      Amount: Math.round(amount),
      PartyA: this.shortcode,
      PartyB: formattedPhone,
      Remarks: remarks,
      QueueTimeOutURL: `${this.callbackUrl}/timeout`,
      ResultURL: `${this.callbackUrl}/result`,
      Occasion: 'Payout',
    };

    try {
      const response = await axios.post(
        'https://sandbox.safaricom.co.ke/mpesa/b2c/v1/paymentrequest',
        payload,
        { headers: { Authorization: `Bearer ${token}` } }
      );
      return response.data;
    } catch (error) {
      throw new InternalServerErrorException('M-Pesa B2C payout failed to initiate');
    }
  }
}
