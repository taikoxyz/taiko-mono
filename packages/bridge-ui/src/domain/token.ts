import type { ComponentType } from 'svelte';
import type { Address } from 'wagmi';

import type { ChainID } from './chain';

export type Token = {
  name: string;
  addresses: Record<ChainID, Address>;
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
