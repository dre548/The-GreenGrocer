import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Request } from 'express';

@Injectable()
export class AuthGuard {
  constructor(private jwtService: JwtService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const token = this.extractTokenFromHeader(request);
    
    if (!token) {
      throw new UnauthorizedException('No token found! Access denied.');
    }
    
    try {
      // Verify the token using the same secret key we used to create it
      const payload = await this.jwtService.verifyAsync(token, {
        secret: 'GREEN_GROCER_SUPER_SECRET_KEY',
      });
      // Attach the decoded payload (which contains the phone and role) to the request
      request['user'] = payload;
    } catch {
      throw new UnauthorizedException('Invalid or expired token.');
    }
    return true;
  }

  private extractTokenFromHeader(request: Request): string | undefined {
    const [type, token] = request.headers.authorization?.split(' ') ?? [];
    return type === 'Bearer' ? token : undefined;
  }
}