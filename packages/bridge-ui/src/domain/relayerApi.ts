import type { BridgeTransaction } from './transactions';

export interface RelayerAPI {
  getAllBridgeTransactionByAddress(
    address: string,
    chainID?: number,
  ): Promise<BridgeTransaction[]>;

  getBlockInfo(): Promise<Map<number, RelayerBlockInfo>>;
}

export type APIResponseTransaction = {
  id: number;
  name: string;
  data: {
    [key: string]: any;
  };
  status: number;
  eventType: number;
  chainID: number;
  canonicalTokenAddress: string;
  canonicalTokenSymbol: string;
  canonicalTokenName: string;
  canonicalTokenDecimals: number;
  amount: string;
  msgHash: string;
  messageOwner: string;
  event: string;
};

export type RelayerBlockInfo = {
  chainId: number;
  latestProcessedBlock: number;
  latestBlock: number;
};

export type APIRequestParams = {
  address: string;
  chainID?: number;
  event?: string;
};

export type APIResponse = {
  items: APIResponseTransaction[];
  page: number;
  size: number;
  max_page: number;
  total_pages: number;
  total: number;
  last: boolean;
  first: boolean;
  visible: number;
};
