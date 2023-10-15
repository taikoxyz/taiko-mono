import { vi } from 'vitest';

// TODO: we might no need this at all

export const getWalletClient = vi.fn();

export const getPublicClient = vi.fn();

export const getContract = vi.fn();

export const fetchBalance = vi.fn();

export const fetchToken = vi.fn();

export const readContract = vi.fn();

export const configureChains = vi.fn(() => {
  return { publicClient: 'mockPublicClient' };
});

export const createConfig = vi.fn(() => {
  return 'mockWagmiConfig';
});
