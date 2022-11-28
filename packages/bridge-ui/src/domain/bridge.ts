import type { BigNumber, ethers, Transaction } from "ethers";

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
  bridgeAddress: string;
  processingFeeInWei?: BigNumber;
  tokenId?: string;
  memo?: string;
};

interface Bridge {
  RequiresAllowance(opts: ApproveOpts): Promise<boolean>;
  Approve(opts: ApproveOpts): Promise<Transaction>;
  Bridge(opts: BridgeOpts): Promise<Transaction>;
}

export { ApproveOpts, BridgeOpts, BridgeType, Bridge };
