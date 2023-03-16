import type { BridgeTransaction } from './transactions';

export const MAX_PAGE_SIZE = 10;
export const DEFAULT_PAGE = 0;

export type GetAllByAddressResponse = {
  txs: BridgeTransaction[];
  paginationResponse: PaginationResponse;
};
export interface RelayerAPI {
  GetAllByAddress(
    address: string,
    pagination: PaginationParams,
    chainID?: number,
  ): Promise<GetAllByAddressResponse>;

  GetBlockInfo(): Promise<Map<number, RelayerBlockInfo>>;
}

export type RelayerBlockInfo = {
  chainId: number;
  latestProcessedBlock: number;
  latestBlock: number;
};

export type PaginationParams = {
  size: typeof MAX_PAGE_SIZE;
  page: number;
};

export type PaginationResponse = {
  size: typeof MAX_PAGE_SIZE;
  page: number;
  maxPage: number;
  totalPages: number;
  first: boolean;
  last: boolean;
};
