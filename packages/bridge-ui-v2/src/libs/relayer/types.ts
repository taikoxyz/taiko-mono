import type { Address } from '@wagmi/core';

import type { BridgeTransaction, RelayerMessage } from '$libs/bridge';

export type GetAllByAddressResponse = {
  txs: BridgeTransaction[];
  paginationInfo: PaginationInfo;
};

export type PaginationParams = {
  size: number;
  page: number;
};

export enum TxExtendedStatus {
  Pending = 'Pending',
  Claiming = 'Claiming',
  Releasing = 'Releasing',
  Released = 'Released',
}

export interface RelayerAPI {
  getTransactionsFromAPI(params: APIRequestParams): Promise<APIResponse>;
  getAllBridgeTransactionByAddress(
    address: Address,
    paginationParams: PaginationParams,
    chainID?: number,
  ): Promise<GetAllByAddressResponse>;
  getBlockInfo(): Promise<Map<number, RelayerBlockInfo>>;
}

export type TransactionData = {
  Message: RelayerMessage;
  Raw: {
    address: Address;
    transactionHash: string;
    transactionIndex: string;
  };
};

export type APIResponseTransaction = {
  id: number;
  name: string;
  data: TransactionData;
  status: number;
  eventType: number;
  chainID: number;
  canonicalTokenAddress: Address;
  canonicalTokenSymbol: string;
  canonicalTokenName: string;
  canonicalTokenDecimals: number;
  amount: string;
  msgHash: string;
  messageOwner: Address;
  event: string;
};

export type RelayerBlockInfo = {
  chainID: number;
  latestProcessedBlock: number;
  latestBlock: number;
};

export type APIRequestParams = {
  address: Address;
  chainID?: number;
  event?: string;
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

export type APIResponse = PaginationInfo & {
  items: APIResponseTransaction[];
  visible: number;
};

export type RelayerConfig = {
  chainIds: number[];
  url: string;
};

export type ConfiguredRelayer = {
  configuredRelayer: RelayerConfig[];
};
