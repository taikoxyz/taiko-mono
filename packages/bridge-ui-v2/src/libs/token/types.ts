import type { Address } from 'abitype';

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
  NOT_CONNECTED = 'NOT_CONNECTED',
  TOKEN_MINTED = 'TOKEN_MINTED',
  INSUFFICIENT_BALANCE = 'INSUFFICIENT_BALANCE',
}
