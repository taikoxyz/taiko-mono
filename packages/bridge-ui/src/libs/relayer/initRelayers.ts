import { configuredRelayer } from '$relayerConfig';

import { RelayerAPIService } from './RelayerAPIService';

class RelayerServiceFactory {
  private static instanceCache: Map<string, RelayerAPIService> = new Map();

  public static getServices(configuredRelayers: { url: string }[]): RelayerAPIService[] {
    return configuredRelayers.map((relayerConfig) => this.getService(relayerConfig.url));
  }

  private static getService(url: string): RelayerAPIService {
    if (!this.instanceCache.has(url)) {
      const newInstance = new RelayerAPIService(url);
      this.instanceCache.set(url, newInstance);
    }
    return this.instanceCache.get(url)!;
  }
}

export const relayerApiServices: RelayerAPIService[] = RelayerServiceFactory.getServices(configuredRelayer);
