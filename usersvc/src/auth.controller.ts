import { Body, Controller, Get, Headers, Post, UnauthorizedException } from '@nestjs/common';
import { IsNotEmpty, IsString, MinLength } from 'class-validator';
import { AuthService } from './auth.service';

class LoginDto {
  @IsString()
  @IsNotEmpty()
  username!: string;

  @IsString()
  @MinLength(6)
  password!: string;
}

@Controller()
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('auth/login')
  async login(@Body() dto: LoginDto) {
    return this.auth.loginWithKeycloak(dto.username, dto.password);
  }

  @Get('api/me')
  async me(@Headers('authorization') authz?: string) {
    if (!authz?.startsWith('Bearer ')) throw new UnauthorizedException('Missing bearer token');
    const token = authz.slice('Bearer '.length);
    const payload = await this.auth.verifyJwtWithKeycloak(token);
    return {
      sub: payload.sub,
      preferred_username: payload.preferred_username,
      email: payload.email
    };
  }
}
