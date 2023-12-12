import { vi } from 'vitest';

// TODO: we might no need this at all

export const getWalletClient = vi.fn();

export const getPublicClient = vi.fn();

export const getContract = vi.fn();

export const fetchBalance = vi.fn();

export const fetchToken = vi.fn();

export const readContract = vi.fn();

const mockChains = [
  {
    id: 0,
    name: 'Debug',
    network: 'Debug',
    nativeCurrency: {
      name: 'ETH',
      symbol: 'ETH',
      decimals: 18,
    },
    rpcUrls: {
      public: { http: ['some/url/'] },
      default: { http: ['some/url/'] },
    },
  },
];

const mockPublicClient = () => {
  return {};
};

export const configureChains = vi.fn().mockReturnValue({
  chains: mockChains,
  publicClient: mockPublicClient,
});

export const createConfig = vi.fn(() => {
  return 'mockWagmiConfig';
});
