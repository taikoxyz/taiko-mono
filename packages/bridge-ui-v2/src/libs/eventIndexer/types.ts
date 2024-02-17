import type { Address } from 'viem';

import type { ChainID } from '$libs/chain';
import type { Token } from '$libs/token';

export type GetAllByAddressResponse = {
  nfts: Token[];
  paginationInfo: PaginationInfo;
};

export type PaginationParams = {
  size: number;
  page: number;
};

export interface EventIndexerAPI {
  getNftsByAddress(params: EventIndexerAPIRequestParams): Promise<EventIndexerAPIResponse>;
}

export type EventIndexerAPIResponseNFT = {
  id: number;
  tokenID: string;
  contractAddress: Address;
  contractType: string;
  address: Address;
  chainID: number;
  amount: number;
};

export type EventIndexerAPIRequestParams = {
  address: Address;
  chainID?: ChainID;
};

export type PaginationInfo = {
  page: number;
  size: number;
  max_page: number;
  total_pages: number;
  total: number;
  last: boolean;
  first: boolean;
};

export type EventIndexerAPIResponse = PaginationInfo & {
  items: EventIndexerAPIResponseNFT[];
  visible: number;
};

export type EventIndexerConfig = {
  chainIds: number[];
  url: string;
};

export type ConfiguredEventIndexer = {
  configuredEventIndexer: EventIndexerConfig[];
};
