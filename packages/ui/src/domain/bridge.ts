import type { BigNumber, ethers, Transaction } from "ethers";

enum BridgeType {
  ERC20 = "ERC20",
  ETH = "ETH",
  ERC721 = "ERC721",
  ERC1155 = "ERC1155",
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
};

type BridgeBackOpts = {
  amount: string;
  signer: ethers.Signer;
  tokenAddress: string;
  name: string;
  symbol: string;
  decimals?: number;
  tokenId?: string;
};

interface Bridge {
  Allowance(opts: ApproveOpts): Promise<BigNumber>;
  Approve(opts: ApproveOpts): Promise<Transaction>;
  Bridge(opts: BridgeOpts): Promise<Transaction>;
  BridgeBack(opts: BridgeBackOpts): Promise<Transaction>;
  WaitForOtherLayerConfirmation(
    tokenAddress: string,
    amount: string,
    from: string
  ): Promise<Transaction>;
}

export {
  ApproveOpts,
  BridgeOpts,
  BridgeBackOpts,
  BridgeStatus,
  BridgeType,
  Bridge,
  BridgeMechanism,
};
