import type { Address } from 'viem';

export enum TokenType {
  ETH = 'ETH',

  // https://ethereum.org/en/developers/docs/standards/tokens/erc-20/
  ERC20 = 'ERC20',

  // https://ethereum.org/en/developers/docs/standards/tokens/erc-721/
  ERC721 = 'ERC721',

  // https://ethereum.org/en/developers/docs/standards/tokens/erc-1155/
  ERC1155 = 'ERC1155',
}

export type Token = {
  name: string;
  addresses: Record<string, Address>;
  symbol: string;
  decimals: number;
  type: TokenType;
  logoURI?: string;
  imported?: boolean;
  mintable?: boolean;
};

export type TokenDetails = {
  name: string;
  address: Address;
  symbol: string;
  balance: bigint;
  decimals: number;
  type: TokenType;
};

export type GetCrossChainAddressArgs = {
  token: Token;
  srcChainId: number;
  destChainId: number;
};

export interface TokenService {
  storeToken(token: Token, address: string): Token[];
  getTokens(address: string): Token[];
  removeToken(token: Token, address: string): Token[];
  updateToken(token: Token, address: string): Token[];
}
