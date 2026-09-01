import type { Address, Hash, Hex } from 'viem';

import type { BridgeTransaction, RelayerMessage } from '$libs/bridge';

// Enough of a transaction to recognise it again. Identities rather than a tally, because the
// caller has to reconcile these against the finished list: the relayer may return the same
// message on more than one page or from more than one relayer, and a message that failed here
// can still reach the list from somewhere else. Both fields are carried because the two sides
// of that comparison are not always identified the same way - see `isSameBridgeTx`.
export type FailedBridgeTx = Pick<BridgeTransaction, 'msgHash' | 'srcTxHash'>;

export type GetAllByAddressResponse = {
  txs: BridgeTransaction[];
  paginationInfo: PaginationInfo;
  // The messages the relayer returned but whose on-chain enhancement threw (typically a
  // rate-limited RPC).
  // Required, not optional: an optional field would let a caller drop it on the way to the UI
  // without the type checker noticing.
  failedTxs: FailedBridgeTx[];
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
  msgHash: Hash;
  messageOwner: Address;
  event: string;
  claimedBy: Address;
  processedTxHash: Hash;
  fee: string;
  isProfitable: boolean;
  isProfitableEvaluatedAt: string;
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
