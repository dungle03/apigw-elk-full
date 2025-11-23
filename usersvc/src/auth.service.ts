import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import axios from 'axios';
import { createRemoteJWKSet, jwtVerify, JWTPayload } from 'jose';

@Injectable()
export class AuthService {
  // Được render từ scripts/render-kong.ps1 dựa trên PUBLIC_IP (KEYCLOAK_REALM_BASE)
  private kcRealmBase = 'http://18.139.209.233:8080/realms/demo';
  private readonly logger = new Logger(AuthService.name);

  async loginWithKeycloak(username: string, password: string) {
    try {
      const url = `${this.kcRealmBase}/protocol/openid-connect/token`;
      const params = new URLSearchParams({
        grant_type: 'password',
        client_id: 'usersvc-client',
        username,
        password,
      });
      const { data } = await axios.post(url, params);
      this.logger.log(`Login success for user "${username}"`);
      return { access_token: data.access_token, expires_in: data.expires_in };
    } catch (e: any) {
      const errorDetails = e.response ? e.response.data : e.message;
      this.logger.warn(`Login failed for user "${username}"`, errorDetails);
      throw new UnauthorizedException('Invalid credentials');
    }
  }

  async verifyJwtWithKeycloak(token: string): Promise<JWTPayload> {
    try {
      const issuer = this.kcRealmBase;
      const jwks = createRemoteJWKSet(new URL(`${issuer}/protocol/openid-connect/certs`));
      const { payload } = await jwtVerify(token, jwks, { issuer });
      this.logger.log(`Token verified for subject "${payload.sub}"`);
      return payload;
    } catch (e) {
      this.logger.warn('Token verification failed');
      throw new UnauthorizedException('Invalid token');
    }
  }
}
