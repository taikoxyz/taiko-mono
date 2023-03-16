import { writable } from 'svelte/store';
import type { RelayerAPI, RelayerBlockInfo } from '../domain/relayerApi';
import { DEFAULT_PAGE, MAX_PAGE_SIZE } from '../domain/relayerApi';
import type {
  PaginationParams,
  PaginationResponse,
} from '../domain/relayerApi';

const relayerApi = writable<RelayerAPI>();
const relayerBlockInfoMap = writable<Map<number, RelayerBlockInfo>>();
const paginationParams = writable<PaginationParams>({
  size: MAX_PAGE_SIZE,
  page: DEFAULT_PAGE,
});
const paginationResponse = writable<PaginationResponse>();

export {
  paginationResponse,
  paginationParams,
  relayerApi,
  relayerBlockInfoMap,
};
