import type { Address, Hex } from 'viem';

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
    transactionHash: Hex;
    transactionIndex: string;
    blockNumber: Hex;
  };
};

export enum RelayerEventType {
  ETH = 0,
  ERC20 = 1,
  ERC721 = 2,
  ERC1155 = 3,
}

export type APIResponseTransaction = {
  id: number;
  name: string;
  data: TransactionData;
  status: number;
  eventType: RelayerEventType;
  chainID: number;
  canonicalTokenAddress: Address;
  canonicalTokenSymbol: string;
  canonicalTokenName: string;
  canonicalTokenDecimals: number;
  amount: string;
  msgHash: Hex;
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

export const FeeTypes = {
  Eth: 'eth',
  Erc20Deployed: 'erc20Deployed',
  Erc20NotDeployed: 'erc20NotDeployed',
  Erc721Deployed: 'erc721Deployed',
  Erc721NotDeployed: 'erc721NotDeployed',
  Erc1155NotDeployed: 'erc1155NotDeployed',
  Erc1155Deployed: 'erc1155Deployed',
} as const;

export type FeeType = (typeof FeeTypes)[keyof typeof FeeTypes];

export type Fee = {
  type: FeeType;
  amount: string;
  destChainID: number;
};

export type ProcessingFeeApiResponse = { fees: Fee[] };
