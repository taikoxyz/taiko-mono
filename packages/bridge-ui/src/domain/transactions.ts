import type { BigNumber, ethers } from "ethers";
import type { Message, MessageStatus } from "./message";

export type BridgeTransaction = {
  ethersTx: ethers.Transaction;
  receipt?: ethers.providers.TransactionReceipt;
  status: MessageStatus;
  signal?: string;
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
    chainID?: number
  ): Promise<BridgeTransaction[]>;
}
