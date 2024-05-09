import { type NFT, type NFTMetadata, type Token, TokenType } from '$libs/token/types';

import { L1_CHAIN_ID } from './chains';

const base64Image =
  'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzIwIiBoZWlnaHQ9IjMyMCIgdmlld0JveD0iMCAwIDMyMCAzMjAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgc2hhcGUtcmVuZGVyaW5nPSJjcmlzcEVkZ2VzIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZDVkN2UxIiAvPjxyZWN0IHdpZHRoPSIxNDAiIGhlaWdodD0iMTAiIHg9IjkwIiB5PSIyMTAiIGZpbGw9IiNmZmZkZjIiIC8+PC9zdmc+';
export const base64Metadata =
  'eyJuYW1lIjoiTW9jayBOYW1lIiwgImRlc2NyaXB0aW9uIjoibW9jayBkZXNjcmlwdGlvbiIsICJpbWFnZSI6ICJkYXRhOmltYWdlL3N2Zyt4bWw7YmFzZTY0LFBITjJaeUIzYVdSMGFEMGlNekl3SWlCb1pXbG5hSFE5SWpNeU1DSWdkbWxsZDBKdmVEMGlNQ0F3SURNeU1DQXpNakFpSUhodGJHNXpQU0pvZEhSd09pOHZkM2QzTG5jekxtOXlaeTh5TURBd0wzTjJaeUlnYzJoaGNHVXRjbVZ1WkdWeWFXNW5QU0pqY21semNFVmtaMlZ6SWo0OGNtVmpkQ0IzYVdSMGFEMGlNVEF3SlNJZ2FHVnBaMmgwUFNJeE1EQWxJaUJtYVd4c1BTSWpaRFZrTjJVeElpQXZQanh5WldOMElIZHBaSFJvUFNJeE5EQWlJR2hsYVdkb2REMGlNVEFpSUhnOUlqa3dJaUI1UFNJeU1UQWlJR1pwYkd3OUlpTm1abVprWmpJaUlDOCtQQzl6ZG1jKyJ9';

export const MOCK_METADATA = {
  name: 'Mock Name',
  description: 'mock description',
  image: 'image/mock.png',
  external_url: 'mock/external_url',
} satisfies NFTMetadata;

export const MOCK_ERC721 = {
  name: 'MockERC721',
  addresses: { 1: '0x123624fe5f48128B48F9D20428D33B89Bf7a3456', 2: '0x3456FE5F48128B48f9d20428d33B89BF7A123624' },
  symbol: 'MERC721',
  decimals: 18,
  type: TokenType.ERC721,
  metadata: MOCK_METADATA,
  tokenId: 42,
} satisfies NFT;

export const MOCK_ERC1155 = {
  name: 'MockERC721',
  addresses: { 1: '0x123624fe5f48128B48F9D20428D33B89Bf7a3456', 2: '0x3456FE5F48128B48f9d20428d33B89BF7A123624' },
  symbol: 'MERC721',
  decimals: 18,
  type: TokenType.ERC1155,
  metadata: MOCK_METADATA,
  tokenId: 42,
} satisfies NFT;

export const MOCK_ERC721_BASE64 = {
  ...MOCK_ERC721,
  uri: base64Metadata,
};

export const MOCK_METADATA_BASE64 = {
  name: 'Mock Name',
  description: 'mock description',
  image: base64Image,
  external_url: undefined,
} satisfies NFTMetadata;

export const MOCK_ERC20 = {
  name: 'MockERC20',
  addresses: {
    [L1_CHAIN_ID]: '0x123624fe5f48128B48F9D20428D33B89Bf7a3456',
    2: '0x3456FE5F48128B48f9d20428d33B89BF7A123624',
  },
  symbol: 'MERC20',
  decimals: 18,
  type: 'ERC20' as TokenType,
} satisfies Token;
