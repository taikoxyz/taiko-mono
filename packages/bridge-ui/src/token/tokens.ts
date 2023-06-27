import Bull from '../components/icons/Bull.svelte';
import Eth from '../components/icons/ETH.svelte';
import Horse from '../components/icons/Horse.svelte';
import Tko from '../components/icons/TKO.svelte';
import Unknown from '../components/icons/Unknown.svelte';
import { L1_CHAIN_ID, L2_CHAIN_ID, TEST_ERC20 } from '../constants/envVars';
import type { Token } from '../domain/token';

export const ETHToken: Token = {
  name: 'Ethereum',
  addresses: {
    [L1_CHAIN_ID]: '0x00',
    [L2_CHAIN_ID]: '0x00',
  },
  decimals: 18,
  symbol: 'ETH',
  logoComponent: Eth,
};

export const TKOToken: Token = {
  name: 'Taiko',
  addresses: {
    [L1_CHAIN_ID]: '0x00',
    [L2_CHAIN_ID]: '0x00',
  },
  decimals: 18,
  symbol: 'TKO',
  logoUrl:
    'https://github.com/taikoxyz/taiko-mono/tree/main/packages/branding/testnet-token-images/ttko.svg',
  logoComponent: Tko,
};

const symbolToLogoComponent = {
  BLL: Bull,
  HORSE: Horse,
  // Add more symbols
};

export const testERC20Tokens: Token[] = TEST_ERC20.map(
  ({ name, address, symbol, logoUrl }) => ({
    name,
    symbol,

    addresses: {
      [L1_CHAIN_ID]: address,
      [L2_CHAIN_ID]: '0x00',
    },
    decimals: 18,
    logoComponent: symbolToLogoComponent[symbol] || Unknown,
    logoUrl: logoUrl,
  }),
);

export const tokens = [ETHToken, ...testERC20Tokens];

export function isTestToken(token: Token): boolean {
  const testingTokens = TEST_ERC20.map((testToken) =>
    testToken.symbol.toLocaleLowerCase(),
  );
  return testingTokens.includes(token.symbol.toLocaleLowerCase());
}

export function isETH(token: Token): boolean {
  return (
    token.symbol.toLocaleLowerCase() === ETHToken.symbol.toLocaleLowerCase()
  );
}

export function isERC20(token: Token): boolean {
  return !isETH(token);
}
