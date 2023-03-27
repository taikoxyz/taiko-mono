import { providers } from '../provider/providers';
import { RELAYER_URL } from '../constants/envVars';
import { RelayerAPIService } from './RelayerAPIService';

export const relayerApi = new RelayerAPIService(RELAYER_URL, providers);
