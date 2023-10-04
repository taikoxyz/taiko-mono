import { fetchToken, type FetchTokenResult } from '@wagmi/core';
import { type Address, zeroAddress } from 'viem';

import { UnknownTokenTypeError } from '$libs/error';

import { detectContractType } from './detectContractType';
import { getTokenInfoFromAddress } from './getTokenInfo';
import { TokenType } from './types';

vi.mock('@wagmi/core');

vi.mock('./errors', () => {
  return {
    UnknownTypeError: vi.fn().mockImplementation(() => {
      return { message: 'Mocked UnknownTypeError' };
    }),
  };
});

vi.mock('./detectContractType', () => {
  const actual = vi.importActual('./detectContractType');
  return {
    ...actual,
    detectContractType: vi.fn(),
  };
});

describe('getTokenInfoFromAddress', () => {
  afterEach(() => {
    vi.clearAllMocks();
  });

  it('should return correct token details for ERC20 tokens', async () => {
    // Given
    const address: Address = zeroAddress;
    vi.mocked(detectContractType).mockResolvedValue(TokenType.ERC20);
    vi.mocked(fetchToken).mockResolvedValue({
      name: 'MockToken',
      symbol: 'MTK',
      decimals: 18,
    } as FetchTokenResult);

    // When
    const result = await getTokenInfoFromAddress(address);

    // Then
    expect(result).toEqual({
      address,
      name: 'MockToken',
      symbol: 'MTK',
      decimals: 18,
    });
  });

  // ...repeat similar structure for ERC1155 and ERC721 token types

  it('should return null for unknown token types', async () => {
    // Given
    const address: Address = zeroAddress;
    vi.mocked(detectContractType).mockRejectedValue(new UnknownTokenTypeError());

    // When
    const result = await getTokenInfoFromAddress(address);

    // Then
    expect(result).toBeNull();
  });
});
