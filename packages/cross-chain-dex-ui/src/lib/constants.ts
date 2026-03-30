import { Token } from '../types';

// L1 native currency — defaults to xDAI (Gnosis), configurable for devnets
export const L1_NATIVE_SYMBOL = (import.meta.env.VITE_L1_NATIVE_SYMBOL as string) || 'xDAI';
export const L1_NATIVE_NAME = (import.meta.env.VITE_L1_NATIVE_NAME as string) || L1_NATIVE_SYMBOL;
export const L1_CHAIN_NAME = (import.meta.env.VITE_L1_CHAIN_NAME as string) || 'Gnosis';

export const ETH_TOKEN: Token = {
  symbol: L1_NATIVE_SYMBOL,
  name: L1_NATIVE_NAME,
  decimals: 18,
  address: null,
  logo: (import.meta.env.VITE_L1_NATIVE_LOGO as string) || '/xdai-logo.svg',
};

export const USDC_TOKEN: Token = {
  symbol: 'USDC',
  name: 'USD Coin',
  decimals: Number(import.meta.env.VITE_USDC_DECIMALS || '18'),
  address: import.meta.env.VITE_USDC_TOKEN as `0x${string}`,
  logo: '/usdc-logo.svg',
};

export const TOKENS = [ETH_TOKEN, USDC_TOKEN];

// Fee constants (matching SimpleDEX contract)
export const FEE_NUMERATOR = 3n;
export const FEE_DENOMINATOR = 1000n;
export const FEE_PERCENT = 0.3;

// Safe v1.4.1 contract addresses (canonical, same on all chains)
export const SAFE_PROXY_FACTORY = (import.meta.env.VITE_SAFE_PROXY_FACTORY as `0x${string}`) || '0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67';
export const SAFE_SINGLETON = (import.meta.env.VITE_SAFE_SINGLETON as `0x${string}`) || '0x29fcB43b46531BcA003ddC8FCB67FFE91900C762';
export const SAFE_MULTISEND = (import.meta.env.VITE_SAFE_MULTISEND as `0x${string}`) || '0x38869bf66a61cF6bDB996A6aE40D5853Fd43B526';
export const SAFE_FALLBACK_HANDLER = (import.meta.env.VITE_SAFE_FALLBACK_HANDLER as `0x${string}`) || '0xfd0732Dc9E303f09fCEf3a7388Ad10A83459Ec99';

// Contract addresses
export const L1_VAULT = import.meta.env.VITE_L1_VAULT as `0x${string}`;
export const SIMPLE_DEX = import.meta.env.VITE_SIMPLE_DEX as `0x${string}`;

// Bridge
export const L1_BRIDGE = import.meta.env.VITE_L1_BRIDGE as `0x${string}`;
export const L2_BRIDGE = (import.meta.env.VITE_L2_BRIDGE as `0x${string}`) || '0x7633740000000000000000000000000000000001';
export const L2_CHAIN_ID = Number(import.meta.env.VITE_L2_CHAIN_ID || '763374');
export const L2_RELAY = (import.meta.env.VITE_L2_RELAY as `0x${string}`) || '0xFf3F45cD388f33f7AaBa43CF705F3f8D09911412';

// RPC URLs
export const L1_RPC_URL = import.meta.env.VITE_L1_RPC_URL as string;
export const L2_RPC_URL = import.meta.env.VITE_L2_RPC_URL as string;
export const BUILDER_RPC_URL = import.meta.env.VITE_BUILDER_RPC_URL as string;

// Chain ID
export const CHAIN_ID = Number(import.meta.env.VITE_CHAIN_ID || '31337');

// Slippage tolerance (0.5%)
export const DEFAULT_SLIPPAGE = 0.5;

// Explorer base URL for transaction links
export const EXPLORER_URL = (import.meta.env.VITE_EXPLORER_URL as string) || 'https://gnosisscan.io';
