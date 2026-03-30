import { Address } from 'viem';

export interface Token {
  symbol: string;
  name: string;
  decimals: number;
  address: Address | null; // null for ETH
  logo: string;
}

export interface UserOp {
  target: Address;
  value: bigint;
  data: `0x${string}`;
}

export interface SwapParams {
  tokenIn: Token;
  tokenOut: Token;
  amountIn: bigint;
  minAmountOut: bigint;
  recipient: Address;
}

export interface SwapQuote {
  amountOut: bigint;
  priceImpact: number;
  fee: bigint;
  rate: number;
  insufficientLiquidity: boolean;
}

export interface DexReserves {
  ethReserve: bigint;
  tokenReserve: bigint;
}

export type SwapDirection = 'ETH_TO_USDC' | 'USDC_TO_ETH';

export type BridgeDirection = 'L1_TO_L2' | 'L2_TO_L1';

export type ActiveTab = 'swap' | 'bridge' | 'liquidity';

export type TxOverlayPhase =
  | 'idle'
  | 'signing'
  | 'sequencing'
  | 'proposing'
  | 'proving'
  | 'complete'
  | 'rejected';

export interface TxOverlayState {
  phase: TxOverlayPhase;
  txHash?: string;
  errorMessage?: string;
}
