import { providers } from '../provider/providers';
import { StorageService } from './StorageService';

export const storageService = new StorageService(localStorage, providers);
