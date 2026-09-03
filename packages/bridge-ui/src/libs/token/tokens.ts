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

const hasAttribute = (token: Token, attribute: TokenAttributeKey): boolean => {
  if (!token.attributes) return false;
  return token.attributes.some((attr) => attr[attribute] === true);
};

export const isWrapped = (token: Token): boolean => hasAttribute(token, TokenAttributeKey.Wrapped);
export const isStablecoin = (token: Token): boolean => hasAttribute(token, TokenAttributeKey.Stablecoin);
export const isMintable = (token: Token): boolean => hasAttribute(token, TokenAttributeKey.Mintable);

// Only an explicit `supported: false` opts a token out; a token that says nothing is supported.
// This used to demand an explicit opt-in and was read by nothing, so a configured entry could
// carry a guard that did not exist: mainnet WETH was marked unsupported, pointed at the wrong
// Taiko contract, and was offered for bridging regardless - one way, since the balance on the
// wrong contract read as zero
export const isSupported = (token: Token): boolean =>
  !token.attributes?.some((attr) => attr[TokenAttributeKey.Supported] === false);

// The bridgeable list. The faucet keeps its own view of testERC20Tokens, filtered on `mintable`
export const tokens = [ETHToken, ...testERC20Tokens.filter(isSupported)];
