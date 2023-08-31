import { configuredRelayer } from '$relayerConfig';

import { RelayerAPIService } from './RelayerAPIService';

export const relayerApiServices: RelayerAPIService[] = configuredRelayer.map(
  (relayerConfig) => new RelayerAPIService(relayerConfig.url),
);
