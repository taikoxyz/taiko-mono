import { zeroAddress } from 'viem';

const mockERC20 = {
  name: 'MockERC20',
  addresses: { '1': zeroAddress },
  symbol: 'MTF',
  decimals: 18,
  type: 'ERC20',
};

const mockERC1155 = {
  name: 'MockERC1155',
  addresses: { '1': zeroAddress },
  symbol: 'MNFT',
  balance: 1337n,
  tokenId: 123,
  uri: 'some/uri/123',
  type: 'ERC1155',
};

const mockERC721 = {
  name: 'MockERC721',
  addresses: { '1': zeroAddress },
  symbol: 'MNFT',
  decimals: 18,
  type: 'ERC721',
};

export const customToken = [mockERC20, mockERC1155, mockERC721];
