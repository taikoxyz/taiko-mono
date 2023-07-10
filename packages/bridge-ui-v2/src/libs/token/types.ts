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
  TOKEN_UNDEFINED = 'TOKEN_UNDEFINED',
  NETWORK_UNDEFINED = 'NETWORK_UNDEFINED',
  NOT_CONNECTED = 'NOT_CONNECTED',
  WRONG_CHAIN = 'WRONG_CHAIN',
  TOKEN_MINTED = 'TOKEN_MINTED',
  INSUFFICIENT_BALANCE = 'INSUFFICIENT_BALANCE',
}
