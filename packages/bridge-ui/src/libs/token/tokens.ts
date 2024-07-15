import { zeroAddress } from 'viem';

import { customToken } from '$customToken';
import { getConfiguredChainIds } from '$libs/chain';

import { type Token, TokenAttributeKey, TokenType } from './types';

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

export const getTokensByType = (type: TokenType): Token[] => tokens.filter((token) => token.type === type);

const hasAttribute = (token: Token, attribute: TokenAttributeKey): boolean => {
  if (!token.attributes) return false;
  return token.attributes.some((attr) => attr[attribute] === true);
};

export const isWrapped = (token: Token): boolean => hasAttribute(token, TokenAttributeKey.Wrapped);
export const isSupported = (token: Token): boolean => hasAttribute(token, TokenAttributeKey.Supported);
export const isStablecoin = (token: Token): boolean => hasAttribute(token, TokenAttributeKey.Stablecoin);
export const isQuotaLimited = (token: Token): boolean => hasAttribute(token, TokenAttributeKey.QuotaLimited);
export const isMintable = (token: Token): boolean => hasAttribute(token, TokenAttributeKey.Mintable);
