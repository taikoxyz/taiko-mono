import type { BigNumber, ethers } from 'ethers';
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
  fromChainId: number;
  toChainId: number;
};
export interface Transactioner {
  GetAllByAddress(
    address: string,
    chainID?: number,
  ): Promise<BridgeTransaction[]>;

  UpdateStorageByAddress(address: string, txs: BridgeTransaction[]): void;
}
