import type { BigNumber } from 'ethers';

export enum MessageStatus {
  New,
  Retriable,
  Done,
  Failed,
  FailedReleased,
}

export type Message = {
  id: number;
  sender: string;
  srcChainId: BigNumber;
  destChainId: BigNumber;
  owner: string;
  to: string;
  refundAddress: string;
  depositValue: BigNumber;
  callValue: BigNumber;
  processingFee: BigNumber;
  gasLimit: BigNumber;
  data: string;
  memo: string;
};
