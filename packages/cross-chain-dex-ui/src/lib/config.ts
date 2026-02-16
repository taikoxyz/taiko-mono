import { http } from 'wagmi';
import { createConfig } from 'wagmi';
import { injected } from 'wagmi/connectors';
import { createPublicClient, defineChain } from 'viem';
import { L1_RPC_URL, L2_RPC_URL, CHAIN_ID } from './constants';

// Define custom chain for L1
export const surgeL1Chain = defineChain({
  id: CHAIN_ID,
  name: 'Gnosis',
  nativeCurrency: {
    decimals: 18,
    name: 'xDAI',
    symbol: 'xDAI',
  },
  rpcUrls: {
    default: { http: [L1_RPC_URL] },
  },
});

// Wagmi config - only injected wallets (MetaMask, Rabby, etc.)
export const config = createConfig({
  chains: [surgeL1Chain],
  connectors: [injected()],
  transports: {
    [surgeL1Chain.id]: http(L1_RPC_URL),
  },
});

// Public client for L1 (reading)
export const l1PublicClient = createPublicClient({
  chain: surgeL1Chain,
  transport: http(L1_RPC_URL),
});

// Define L2 chain
export const surgeL2Chain = defineChain({
  id: 763374, // L2 chain ID
  name: 'Surge L2',
  nativeCurrency: { decimals: 18, name: 'xDAI', symbol: 'xDAI' },
  rpcUrls: {
    default: { http: [L2_RPC_URL] },
  },
});

// Public client for L2 (reading DEX reserves)
export const l2PublicClient = createPublicClient({
  chain: surgeL2Chain,
  transport: http(L2_RPC_URL),
});
