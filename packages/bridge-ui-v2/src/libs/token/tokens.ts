import { zeroAddress } from 'viem';

import { customToken } from '$customToken';
import { getConfiguredChainIds } from '$libs/chain';

import { type Token, TokenType } from './types';

const chains = getConfiguredChainIds();

const zeroAddressMap = chains.reduce((acc, chainId) => ({ ...acc, [chainId]: zeroAddress }), {});

export const ETHToken: Token = {
  name: 'Ether',
  addresses: zeroAddressMap,
  decimals: 18,
  symbol: 'ETH',
  type: TokenType.ETH,
};

export const testERC20Tokens: Token[] = customToken;

export const tokens = [ETHToken, ...testERC20Tokens];
