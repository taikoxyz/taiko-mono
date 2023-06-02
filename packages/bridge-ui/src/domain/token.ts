import type { Address } from '@wagmi/core';
import type { ComponentType } from 'svelte';

type TokenAddress = {
  chainId: number;
  address: Address;
};

export type Token = {
  name: string;
  addresses: TokenAddress[];
  symbol: string;
  decimals: number;
  logoUrl?: string;
  logoComponent: ComponentType;
};

export type TokenDetails = {
  symbol: string;
  decimals: number;
  address: string;
  balance: string;
};

export interface TokenService {
  storeToken(token: Token, address: string): Token[];
  getTokens(address: string): Token[];
  removeToken(token: Token, address: string): Token[];
}
