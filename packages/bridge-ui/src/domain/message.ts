import type { BigNumber } from "ethers";

enum MessageStatus {
  New,
  Retriable,
  Done,
  Failed,
}

type Message = {
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

export { Message, MessageStatus };
