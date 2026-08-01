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
      // No secret passed here on purpose — JwtService already has it from
      // the global JwtModule config (auth.module.ts), which reads it from
      // JWT_SECRET. Duplicating the secret string in two places is how it
      // ended up hardcoded before.
      const payload = await this.jwtService.verifyAsync(token);
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