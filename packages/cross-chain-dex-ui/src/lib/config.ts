import { http } from 'wagmi';
import { createConfig } from 'wagmi';
import { injected } from 'wagmi/connectors';
import { createPublicClient, defineChain } from 'viem';
import { L1_RPC_URL, L2_RPC_URL, CHAIN_ID, L1_CHAIN_NAME, L1_NATIVE_SYMBOL, L1_NATIVE_NAME } from './constants';

// Define custom chain for L1
export const surgeL1Chain = defineChain({
  id: CHAIN_ID,
  name: L1_CHAIN_NAME,
  nativeCurrency: {
    decimals: 18,
    name: L1_NATIVE_NAME,
    symbol: L1_NATIVE_SYMBOL,
  },
  rpcUrls: {
    default: { http: [L1_RPC_URL] },
  },
});

// Define L2 chain
export const surgeL2Chain = defineChain({
  id: Number(import.meta.env.VITE_L2_CHAIN_ID || '763374'),
  name: 'Surge L2',
  nativeCurrency: { decimals: 18, name: L1_NATIVE_NAME, symbol: L1_NATIVE_SYMBOL },
  rpcUrls: {
    default: { http: [L2_RPC_URL] },
  },
});

// Wagmi config - both L1 and L2 chains
export const config = createConfig({
  chains: [surgeL1Chain, surgeL2Chain],
  connectors: [injected()],
  transports: {
    [surgeL1Chain.id]: http(L1_RPC_URL),
    [surgeL2Chain.id]: http(L2_RPC_URL),
  },
});

// Public client for L1 (reading)
export const l1PublicClient = createPublicClient({
  chain: surgeL1Chain,
  transport: http(L1_RPC_URL),
});

// Public client for L2 (reading DEX reserves)
export const l2PublicClient = createPublicClient({
  chain: surgeL2Chain,
  transport: http(L2_RPC_URL),
});
