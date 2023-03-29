import type { BigNumber, ethers } from 'ethers';
import type { ChainID } from './chain';
import type { Message, MessageStatus } from './message';

export type BridgeTransaction = {
  hash: string;
  from: string;
  receipt?: ethers.providers.TransactionReceipt;
  status: MessageStatus;
  msgHash?: string;
  message?: Message;
  interval?: NodeJS.Timer;
  amountInWei?: BigNumber;
  symbol?: string;
  fromChainId: ChainID;
  toChainId: ChainID;
};

export interface Transactioner {
  getAllByAddress(
    address: string,
    chainID?: number,
  ): Promise<BridgeTransaction[]>;

  getTransactionByHash(
    address: string,
    hash: string,
  ): Promise<BridgeTransaction>;

  updateStorageByAddress(address: string, txs: BridgeTransaction[]): void;
}

export enum ReceiptStatus {
  Failed = 0,
  Successful = 1,
}
