import { configuredEventIndexer } from '../../generated/eventIndexerConfig';
import { EventIndexerAPIService } from './EventIndexerAPIService';

export const eventIndexerApiServices: EventIndexerAPIService[] = configuredEventIndexer.map(
  (eventIndexerConfig: { url: string }) => new EventIndexerAPIService(eventIndexerConfig.url),
);
