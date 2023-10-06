import { fetchToken, type FetchTokenResult, readContract } from '@wagmi/core';
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
      type: TokenType.ERC20,
    });
  });

  it('should return correct token details for ERC721 tokens', async () => {
    // Given
    const address: Address = zeroAddress;
    vi.mocked(detectContractType).mockResolvedValue(TokenType.ERC721);
    vi.mocked(readContract).mockResolvedValueOnce('MockNFT').mockResolvedValueOnce('MNFT');

    // When
    const result = await getTokenInfoFromAddress(address);

    // Then
    expect(result).toEqual({
      address,
      name: 'MockNFT',
      symbol: 'MNFT',
      decimals: 0,
      type: TokenType.ERC721,
    });
  });

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
