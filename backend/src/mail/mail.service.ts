import { Injectable, HttpException, HttpStatus } from '@nestjs/common';
import * as nodemailer from 'nodemailer';

@Injectable()
export class MailService {
  private transporter: nodemailer.Transporter | null = null;

  private getTransporter(): nodemailer.Transporter {
    if (this.transporter) return this.transporter;

    const host = process.env.SMTP_HOST;
    const port = process.env.SMTP_PORT;
    const user = process.env.SMTP_USER;
    const pass = process.env.SMTP_PASS;

    if (!host || !port || !user || !pass) {
      throw new HttpException(
        'Email is not configured on the server: set SMTP_HOST/SMTP_PORT/SMTP_USER/SMTP_PASS in the backend .env.',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }

    this.transporter = nodemailer.createTransport({
      host,
      port: Number(port),
      secure: Number(port) === 465, // true for 465 (SSL), false for 587 (STARTTLS)
      auth: { user, pass },
    });
    return this.transporter;
  }

  async sendOtpEmail(toEmail: string, otp: string) {
    const transporter = this.getTransporter();
    const from = process.env.SMTP_FROM || 'The Greengrocer <no-reply@greengrocer.app>';

    try {
      await transporter.sendMail({
        from,
        to: toEmail,
        subject: 'Your Greengrocer verification code',
        text: `Your verification code is ${otp}. It expires in 5 minutes.`,
        html: `<p>Your verification code is <strong style="font-size:20px">${otp}</strong>.</p><p>It expires in 5 minutes.</p>`,
      });
    } catch (error: any) {
      throw new HttpException(
        `Failed to send OTP email: ${error.message}`,
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }
}
