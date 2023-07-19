import type { BigNumber } from 'ethers';
import type { ChainID } from './chain';

export type PaginationInfo = {
  page: number;
  size: number;
  max_page: number;
  total_pages: number;
  total: number;
  last: boolean;
  first: boolean;
};

export type TransactionData = {
  Raw: {
    address: string;
    transactionHash: string;
    transactionIndex: string;
  };
};

export type APIResponseEvent = {
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
  assignedProver: string;
  blockID: { Int64: number; Valid: boolean };
};

export type APIResponse = PaginationInfo & {
  items: APIResponseEvent[];
  visible: number;
};
