import type {
  PaginationInfo,
  RelayerAPI,
  RelayerBlockInfo,
} from '../domain/relayerApi';
import { writable } from 'svelte/store';

const relayerApi = writable<RelayerAPI>();
const relayerBlockInfoMap = writable<Map<number, RelayerBlockInfo>>();
const paginationInfo = writable<PaginationInfo>();

export { relayerApi, relayerBlockInfoMap, paginationInfo };
