import type { ComponentType } from 'svelte';

type Address = {
  chainId: number;
  address: string;
};

export type Token = {
  name: string;
  addresses: Address[];
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
  StoreToken(token: Token, address: string): Promise<Token[]>;
  GetTokens(address: string): Token[];
  RemoveToken(token: Token, address: string): Token[];
}
