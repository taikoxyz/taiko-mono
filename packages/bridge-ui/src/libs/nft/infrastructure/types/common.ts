import type { Address } from 'viem';

export type FetchNftArgs = {
  address: Address;
  chainId: number;
  refresh: boolean;
};
