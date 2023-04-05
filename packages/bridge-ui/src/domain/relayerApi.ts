import type { Address, ChainID } from './chain';
import type { BridgeTransaction } from './transaction';

export interface RelayerAPI {
  getAllBridgeTransactionByAddress(
    address: string,
    chainID?: number,
  ): Promise<BridgeTransaction[]>;

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
    transactionHash: string;
  };
};

export type APIResponseTransaction = {
  id: number;
  name: string;
  data: TransactionData;
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
  ChainID: ChainID;
  LatestProcessedBlock: number;
  LatestBlock: number;
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
