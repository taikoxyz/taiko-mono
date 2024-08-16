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

export enum TokenAttributeKey {
  Mintable = 'mintable',
  Wrapped = 'wrapped',
  Stablecoin = 'stablecoin',
  Supported = 'supported',
  QuotaLimited = 'quotaLimited',
}

export type TokenAttributes = {
  [TokenAttributeKey.Mintable]?: boolean;
  [TokenAttributeKey.Wrapped]?: boolean;
  [TokenAttributeKey.Stablecoin]?: boolean;
  [TokenAttributeKey.Supported]?: boolean;
  [TokenAttributeKey.QuotaLimited]?: boolean;
};

export type Token = {
  type: TokenType;
  name: string;
  symbol: string;
  addresses: Record<string, Address>;
  decimals: number;
  logoURI?: string;
  imported?: boolean;
  balance?: bigint;
  attributes?: TokenAttributes[];
};

export type NFT = Omit<Token, 'decimals'> & {
  tokenId: number;
  uri?: string;
  metadata?: NFTMetadata;
};

// Based on https://docs.opensea.io/docs/metadata-standards
export type NFTMetadata = {
  description: string;
  external_url?: string;
  image: string;
  name: string;
  //todo: more metadata?
};

export type GetTokenInfo = {
  token: Token | NFT;
  srcChainId: number;
  destChainId: number;
};

export interface TokenService {
  storeToken(token: Token, address: string): Token[];
  getTokens(address: string): Token[];
  removeToken(token: Token, address: string): Token[];
  updateToken(token: Token, address: string): Token[];
}
