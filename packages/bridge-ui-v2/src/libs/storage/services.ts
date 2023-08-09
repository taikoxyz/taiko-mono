import { CustomTokenService } from './CustomTokenService';

export const tokenService = new CustomTokenService(globalThis.localStorage);
