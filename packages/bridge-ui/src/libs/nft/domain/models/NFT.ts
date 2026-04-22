import type { Address } from 'viem';

import type { NFTMetadata, TokenType } from '$libs/token';

export interface NFT {
  type: TokenType;
  name: string;
  symbol: string;
  addresses: Record<string, Address>;
  owner: Address;
  imported?: boolean;
  mintable?: boolean;
  balance: string | number;
  tokenId: number | string;
  uri?: string;
  metadata?: NFTMetadata;
}
