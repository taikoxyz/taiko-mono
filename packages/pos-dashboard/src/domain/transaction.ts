import type { BigNumber, ethers } from 'ethers';

import type { ChainID } from './chain';
import type { Message, MessageStatus } from './message';

// We need this enums for the UI
export enum TxExtendedStatus {
  Pending = 'Pending',
  Claiming = 'Claiming',
  Releasing = 'Releasing',
  Released = 'Released',
}

export type TxUIStatus = MessageStatus | TxExtendedStatus;

export type TransactionReceipt = ethers.providers.TransactionReceipt;

export type BridgeTransaction = {
  hash: string;
  from: string;
  receipt?: TransactionReceipt;
  status: TxUIStatus;
  msgHash?: string;
  message?: Message;
  interval?: NodeJS.Timer;
  amount?: BigNumber;
  symbol?: string;
  decimals?: number;
  srcChainId: ChainID;
  destChainId: ChainID;
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
