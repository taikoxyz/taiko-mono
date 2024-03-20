import { type NFT, type NFTMetadata, TokenType } from '$libs/token/types';

export const MOCK_METADATA = {
  name: 'name',
  description: 'description',
  image: 'image',
  external_url: 'external_url',
} satisfies NFTMetadata;

export const MOCK_ERC721 = {
  name: 'MockERC721',
  addresses: { L1_CHAIN_ID: '0x123', L2_CHAIN_ID: '0x321' },
  symbol: 'MNFT',
  decimals: 18,
  type: TokenType.ERC721,
  metadata: MOCK_METADATA,
  tokenId: 42,
} satisfies NFT;
