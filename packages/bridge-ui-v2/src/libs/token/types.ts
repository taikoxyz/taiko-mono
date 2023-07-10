import type { Address } from 'abitype';

export type Token = {
  name: string;
  addresses: Record<string, Address>;
  symbol: string;
  decimals: number;
};

export type TokenEnv = {
  name: string;
  address: string;
  symbol: string;
};
