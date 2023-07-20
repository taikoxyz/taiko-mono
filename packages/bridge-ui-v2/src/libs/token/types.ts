import type { Address } from 'viem';

export type Token = {
  name: string;
  addresses: Record<string, Address>;
  symbol: string;
  decimals: number;
};

export type TokenEnv = {
  name: string;
  address: Address;
  symbol: string;
};

export enum MintableError {
  TOKEN_MINTED = 'TOKEN_MINTED',
  INSUFFICIENT_BALANCE = 'INSUFFICIENT_BALANCE',
}
