import { Token } from '../types';

export const ETH_TOKEN: Token = {
  symbol: 'xDAI',
  name: 'xDAI',
  decimals: 18,
  address: null,
  logo: '/xdai-logo.svg',
};

export const USDC_TOKEN: Token = {
  symbol: 'USDC',
  name: 'USD Coin',
  decimals: 6, // Real Gnosis USDC has 6 decimals
  address: import.meta.env.VITE_USDC_TOKEN as `0x${string}`,
  logo: '/usdc-logo.svg',
};

export const TOKENS = [ETH_TOKEN, USDC_TOKEN];

// Fee constants (matching SimpleDEX contract)
export const FEE_NUMERATOR = 3n;
export const FEE_DENOMINATOR = 1000n;
export const FEE_PERCENT = 0.3;

// Contract addresses
export const USER_OPS_FACTORY = import.meta.env.VITE_USER_OPS_FACTORY as `0x${string}`;
export const L1_VAULT = import.meta.env.VITE_L1_VAULT as `0x${string}`;
export const SIMPLE_DEX = import.meta.env.VITE_SIMPLE_DEX as `0x${string}`;

// Bridge
export const L1_BRIDGE = import.meta.env.VITE_L1_BRIDGE as `0x${string}`;
export const L2_CHAIN_ID = Number(import.meta.env.VITE_L2_CHAIN_ID || '763374');

// RPC URLs
export const L1_RPC_URL = import.meta.env.VITE_L1_RPC_URL as string;
export const L2_RPC_URL = import.meta.env.VITE_L2_RPC_URL as string;
export const BUILDER_RPC_URL = import.meta.env.VITE_BUILDER_RPC_URL as string;

// Chain ID
export const CHAIN_ID = Number(import.meta.env.VITE_CHAIN_ID || '31337');

// Slippage tolerance (0.5%)
export const DEFAULT_SLIPPAGE = 0.5;
