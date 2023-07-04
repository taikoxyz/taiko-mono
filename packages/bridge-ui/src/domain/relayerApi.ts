import type { Address } from 'wagmi';

import type { ChainID } from './chain';
import type { BridgeTransaction } from './transaction';

export type GetAllByAddressResponse = {
  txs: BridgeTransaction[];
  paginationInfo: PaginationInfo;
};

export type PaginationParams = {
  size: number;
  page: number;
};

export interface RelayerAPI {
  getAllBridgeTransactionByAddress(
    address: Address,
    pagination: PaginationParams,
    chainID?: number,
  ): Promise<GetAllByAddressResponse>;

  getBlockInfo(): Promise<Map<number, RelayerBlockInfo>>;
}

export type TransactionData = {
  Message: {
    Id: number;
    SrcChainId: ChainID;
    DestChainId: ChainID;
    To: string;
    Memo: string;
    Owner: Address;
    Sender: Address;
    GasLimit: string;
    CallValue: string;
    DepositValue: string;
    ProcessingFee: string;
    RefundAddress: Address;
    Data: string;
  };
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
