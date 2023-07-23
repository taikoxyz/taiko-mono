import { zeroAddress } from 'viem';

import { PUBLIC_L1_CHAIN_ID, PUBLIC_L2_CHAIN_ID, PUBLIC_TEST_ERC20 } from '$env/static/public';
import { jsonParseWithDefault } from '$libs/util/jsonParseWithDefault';

import type { Token, TokenEnv } from './types';

export const ETHToken: Token = {
  name: 'Ether',
  addresses: {
    [PUBLIC_L1_CHAIN_ID]: zeroAddress,
    [PUBLIC_L2_CHAIN_ID]: zeroAddress,
  },
  decimals: 18,
  symbol: 'ETH',
};

export const TKOToken: Token = {
  name: 'Taiko',
  addresses: {
    [PUBLIC_L1_CHAIN_ID]: zeroAddress,
    [PUBLIC_L2_CHAIN_ID]: zeroAddress,
  },
  decimals: 8,
  symbol: 'TKO',
};

export const testERC20Tokens: Token[] = jsonParseWithDefault<TokenEnv[]>(PUBLIC_TEST_ERC20, []).map(
  ({ name, address, symbol }) => ({
    name,
    symbol,
    addresses: {
      // They are only deployed on L1
      [PUBLIC_L1_CHAIN_ID]: address,
      [PUBLIC_L2_CHAIN_ID]: zeroAddress,
    },
    decimals: 18,
  }),
);

export const tokens = [ETHToken, ...testERC20Tokens];

export function isETH(token: Token) {
  // Should be fine just by checking the symbol
  return token.symbol.toLocaleLowerCase() === ETHToken.symbol.toLocaleLowerCase();
}

export function isERC20(token: Token): boolean {
  return !isETH(token);
}

export function isTestToken(token: Token): boolean {
  const testTokenSymbols = testERC20Tokens.map((testToken) => testToken.symbol.toLocaleLowerCase());
  return testTokenSymbols.includes(token.symbol.toLocaleLowerCase());
}
