import type { BigNumber } from 'ethers';

import type { ChainID } from './chain';

export enum MessageStatus {
  New,
  Retriable,
  Done,
  Failed,
}

export type Message = {
  id: number;
  sender: string;
  srcChainId: ChainID;
  destChainId: ChainID;
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
