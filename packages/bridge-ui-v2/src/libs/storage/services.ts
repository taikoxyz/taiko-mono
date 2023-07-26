import { BridgeTxService } from './BridgeTxService';
import { CustomTokenService } from './CustomTokenService';

export const bridgeTxService = new BridgeTxService(globalThis.localStorage);

export const customTokenService = new CustomTokenService(globalThis.localStorage);
