import type { BigNumber, ethers, Transaction } from "ethers";

enum BridgeStatus {
  None,
  Approved,
  Waiting,
  Bridged,
}

enum BridgeType {
  ERC20 = "ERC20",
  ETH = "ETH",
  NFT = "NFTs",
}

enum BridgeMechanism {
  Deposit = "Deposit",
  Withdraw = "Withdraw",
}

type ApproveOpts = {
  owner: string;
  amount: string;
  contractAddress: string;
  signer: ethers.Signer;
};

type BridgeOpts = {
  amount: string;
  signer: ethers.Signer;
  tokenAddress: string;
  tokenId?: string;
  destChainId: number;
  bridgeAddress: string;
};

interface Bridge {
  Allowance(opts: ApproveOpts): Promise<BigNumber>;
  Approve(opts: ApproveOpts): Promise<Transaction>;
  Bridge(opts: BridgeOpts): Promise<Transaction>;
}

export {
  ApproveOpts,
  BridgeOpts,
  BridgeStatus,
  BridgeType,
  Bridge,
  BridgeMechanism,
};
