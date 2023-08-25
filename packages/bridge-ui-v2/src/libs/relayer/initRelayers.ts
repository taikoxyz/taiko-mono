import { configuredRelayer } from '$config/relayer';

import { RelayerAPIService } from './RelayerAPIService';

export const relayerApiServices: RelayerAPIService[] = configuredRelayer.map(relayerConfig => new RelayerAPIService(relayerConfig.url));
