import type { BigNumber, ethers, Transaction } from "ethers";
import type { Message } from "./message";

enum BridgeType {
  ERC20 = "ERC20",
  ETH = "ETH",
  ERC721 = "ERC721",
  ERC1155 = "ERC1155",
}

type ApproveOpts = {
  amountInWei: BigNumber;
  contractAddress: string;
  signer: ethers.Signer;
  spenderAddress: string;
};

type BridgeOpts = {
  amountInWei: BigNumber;
  signer: ethers.Signer;
  tokenAddress: string;
  fromChainId: number;
  toChainId: number;
  tokenVaultAddress: string;
  processingFeeInWei?: BigNumber;
  tokenId?: string;
  memo?: string;
};

type ClaimOpts = {
  message: Message;
  signal: string;
  signer: ethers.Signer;
  destBridgeAddress: string;
  srcBridgeAddress: string;
};

interface Bridge {
  RequiresAllowance(opts: ApproveOpts): Promise<boolean>;
  Approve(opts: ApproveOpts): Promise<Transaction>;
  Bridge(opts: BridgeOpts): Promise<Transaction>;
  EstimateGas(opts: BridgeOpts): Promise<BigNumber>;
  Claim(opts: ClaimOpts): Promise<Transaction>;
}

export { ApproveOpts, BridgeOpts, BridgeType, Bridge, ClaimOpts };
