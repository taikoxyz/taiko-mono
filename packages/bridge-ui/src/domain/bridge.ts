import type { BigNumber, ethers, Transaction } from 'ethers';
import ERC20Bridge from '../erc20/bridge';
import ETHBridge from '../eth/bridge';
import { ProofService } from '../proof/service';
import type { Message } from './message';
import type { Prover } from './proof';
import { providers } from './provider';

enum BridgeType {
  ERC20 = 'ERC20',
  ETH = 'ETH',
  ERC721 = 'ERC721',
  ERC1155 = 'ERC1155',
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
  to: string;
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

interface HTMLBridgeForm extends HTMLFormElement {
  customTokenAddress: HTMLInputElement;
}

const prover: Prover = new ProofService(providers);
const ethBridge = new ETHBridge(prover);
const erc20Bridge = new ERC20Bridge(prover);

const bridges = new Map<BridgeType, Bridge>([
  [BridgeType.ETH, ethBridge],
  [BridgeType.ERC20, erc20Bridge],
]);

export {
  ApproveOpts,
  BridgeOpts,
  BridgeType,
  Bridge,
  ClaimOpts,
  ReleaseOpts,
  HTMLBridgeForm,
  bridges,
};
