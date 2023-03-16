import Bull from '../components/icons/Bull.svelte';
import Eth from '../components/icons/ETH.svelte';
import Horse from '../components/icons/Horse.svelte';
import Tko from '../components/icons/TKO.svelte';
import Unknown from '../components/icons/Unknown.svelte';
import { L1_CHAIN_ID, L2_CHAIN_ID } from '../constants/envVars';
import { getEnv } from '../utils/envVar';
import type { Token } from '../domain/token';

export const ETHToken: Token = {
  name: 'Ethereum',
  addresses: [
    {
      chainId: L1_CHAIN_ID,
      address: '0x00',
    },
    {
      chainId: L2_CHAIN_ID,
      address: '0x00',
    },
  ],
  decimals: 18,
  symbol: 'ETH',
  logoComponent: Eth,
};

export const TKOToken: Token = {
  name: 'Taiko',
  addresses: [
    {
      chainId: L1_CHAIN_ID,
      address: '0x00',
    },
    {
      chainId: L2_CHAIN_ID,
      address: '0x00',
    },
  ],
  decimals: 18,
  symbol: 'TKO',
  logoComponent: Tko,
};

const symbolToLogoComponent = {
  BLL: Bull,
  HORSE: Horse,
  // Add more symbols
};

export const testERC20Tokens: Token[] = JSON.parse(
  getEnv(
    'VITE_TEST_ERC20',
    `[{
      "address": "0x3435A6180fBB1BAEc87bDC49915282BfBC328C70",
      "symbol": "BLL",
      "name": "Bull Token"
    }]`,
  ),
).map(({ name, address, symbol }) => ({
  name,
  symbol,

  addresses: [
    {
      chainId: L1_CHAIN_ID,
      address,
    },
    {
      chainId: L2_CHAIN_ID,
      address: '0x00',
    },
  ],
  decimals: 18,
  logoComponent: symbolToLogoComponent[symbol] || Unknown,
}));

export const tokens = [ETHToken, ...testERC20Tokens];
