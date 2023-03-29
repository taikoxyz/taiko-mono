import type { ComponentType } from 'svelte';

export type ChainAddress = {
  chainId: number;
  address: string;
};

export type Token = {
  name: string;
  addresses: ChainAddress[];
  symbol: string;
  decimals: number;
  logoUrl?: string;
  logoComponent: ComponentType;
};

export type TokenDetails = {
  symbol: string;
  decimals: number;
  address: string;
  userTokenBalance: string;
};

export interface TokenService {
  storeToken(token: Token, address: string): Token[];
  getTokens(address: string): Token[];
  removeToken(token: Token, address: string): Token[];
}
