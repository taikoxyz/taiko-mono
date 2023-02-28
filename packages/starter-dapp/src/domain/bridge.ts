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
  isBridgedTokenAlreadyDeployed?: boolean;
};

type ClaimOpts = {
  message: Message;
  msgHash: string;
  signer: ethers.Signer;
  destBridgeAddress: string;
  srcBridgeAddress: string;
};

type ReleaseOpts = {
  message: Message;
  msgHash: string;
  signer: ethers.Signer;
  destBridgeAddress: string;
  srcBridgeAddress: string;
  destProvider: ethers.providers.JsonRpcProvider;
  srcTokenVaultAddress: string;
};

interface Bridge {
  RequiresAllowance(opts: ApproveOpts): Promise<boolean>;
  Approve(opts: ApproveOpts): Promise<Transaction>;
  Bridge(opts: BridgeOpts): Promise<Transaction>;
  EstimateGas(opts: BridgeOpts): Promise<BigNumber>;
  Claim(opts: ClaimOpts): Promise<Transaction>;
  ReleaseTokens(opts: ReleaseOpts): Promise<Transaction>;
}

export { ApproveOpts, BridgeOpts, BridgeType, Bridge, ClaimOpts, ReleaseOpts };
