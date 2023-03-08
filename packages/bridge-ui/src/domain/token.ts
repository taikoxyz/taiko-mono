import Eth from '../components/icons/ETH.svelte';
import type { ComponentType } from 'svelte';
import Tko from '../components/icons/TKO.svelte';
import { CHAIN_MAINNET, CHAIN_TKO } from './chain';
import Horse from '../components/icons/Horse.svelte';
import Bull from '../components/icons/Bull.svelte';
import Unknown from '../components/icons/Unknown.svelte';

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

export const ETH: Token = {
  name: 'Ethereum',
  addresses: [
    {
      chainId: CHAIN_MAINNET.id,
      address: '0x00',
    },
    {
      chainId: CHAIN_TKO.id,
      address: '0x00',
    },
  ],
  decimals: 18,
  symbol: 'ETH',
  logoComponent: Eth,
};

export const TKO: Token = {
  name: 'Taiko',
  addresses: [
    {
      chainId: CHAIN_MAINNET.id,
      address: '0x00',
    },
    {
      chainId: CHAIN_TKO.id,
      address: '0x00',
    },
  ],
  decimals: 18,
  symbol: 'TKO',
  logoComponent: Tko,
};

export const symbolToLogoComponent = {
  BLL: Bull,
  HORSE: Horse,
  // Add more symbols
};

export const TEST_ERC20: Token[] = JSON.parse(
  import.meta.env?.VITE_TEST_ERC20 ??
    // default erc20 token
    `
    [{
      "address": "0x3435A6180fBB1BAEc87bDC49915282BfBC328C70",
      "symbol": "BLL",
      "name": "Bull Token"
    }]
    `,
).map(({ name, address, symbol }) => ({
  name,
  symbol,

  addresses: [
    {
      chainId: CHAIN_MAINNET.id,
      address,
    },
    {
      chainId: CHAIN_TKO.id,
      address: '0x00',
    },
  ],
  decimals: 18,
  logoComponent: symbolToLogoComponent[symbol] || Unknown,
}));

export interface TokenService {
  StoreToken(token: Token, address: string): Promise<Token[]>;
  GetTokens(address: string): Token[];
  RemoveToken(token: Token, address: string): Token[];
}

export const tokens = [ETH, ...TEST_ERC20];
