import { providers } from '../provider/providers';
import { CustomTokenService } from './CustomTokenService';
import { StorageService } from './StorageService';

export const storageService = new StorageService(localStorage, providers);

export const tokenService = new CustomTokenService(localStorage);
