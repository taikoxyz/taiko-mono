import Bull from '../components/icons/Bull.svelte';
import Eth from '../components/icons/ETH.svelte';
import Horse from '../components/icons/Horse.svelte';
import Tko from '../components/icons/TKO.svelte';
import Unknown from '../components/icons/Unknown.svelte';
import { L1_CHAIN_ID, L2_CHAIN_ID, TEST_ERC20 } from '../constants/envVars';
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

export const testERC20Tokens: Token[] = TEST_ERC20.map(
  ({ name, address, symbol }) => ({
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
  }),
);

export const tokens = [ETHToken, ...testERC20Tokens];
