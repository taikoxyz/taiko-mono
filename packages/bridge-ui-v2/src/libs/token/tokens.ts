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

export const testERC20Tokens: Token[] = customToken.filter((token) => token.type === TokenType.ERC20);

export const testNFT: Token[] = customToken.filter(
  (token) => token.type === TokenType.ERC721 || token.type === TokenType.ERC1155,
);

export const tokens = [ETHToken, ...testERC20Tokens];
