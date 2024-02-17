import { createConfig, getToken, type GetTokenReturnType, readContract } from '@wagmi/core';
import { type Address, zeroAddress } from 'viem';

import { customToken } from '$customToken';
import { UnknownTokenTypeError } from '$libs/error';
import { config } from '$libs/wagmi';

import { detectContractType } from './detectContractType';
import { fetchNFTMetadata } from './fetchNFTMetadata';
import { getTokenWithInfoFromAddress } from './getTokenWithInfoFromAddress';
import { type NFT, TokenType } from './types';

vi.mock('@wagmi/core');
vi.mock('./fetchNFTMetadata');
vi.mock('$libs/wagmi/client');

vi.mock('../../generated/customTokenConfig', () => {
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
  return {
    customToken: [mockERC20, mockERC1155, mockERC721],
  };
});

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

describe('getTokenWithInfoFromAddress', () => {
  afterEach(() => {
    vi.clearAllMocks();
  });

  describe('ERC20', () => {
    it('should return correct token details for ERC20 tokens', async () => {
      // Given
      const address: Address = zeroAddress;
      vi.mocked(detectContractType).mockResolvedValue(TokenType.ERC20);
      vi.mocked(getToken).mockResolvedValue({
        name: customToken[0].name,
        symbol: customToken[0].symbol,
        decimals: customToken[0].decimals,
      } as GetTokenReturnType);

      // When
      const result = await getTokenWithInfoFromAddress({ contractAddress: address, srcChainId: 1 });

      // Then
      expect(result).toEqual(customToken[0]);

      expect(getToken).toHaveBeenCalledOnce();
      expect(getToken).toHaveBeenCalledWith(config, {
        address,
        chainId: 1,
      });
    });
  });

  describe('ERC721', () => {
    it('should return correct token details for ERC721 tokens', async () => {
      // Given
      const address: Address = zeroAddress;
      vi.mocked(createConfig);
      vi.mocked(detectContractType).mockResolvedValue(TokenType.ERC721);
      vi.mocked(readContract)
        .mockResolvedValueOnce('Mock721')
        .mockResolvedValueOnce('MNFT')
        .mockResolvedValueOnce('some/uri/123');

      // When
      const result = await getTokenWithInfoFromAddress({ contractAddress: address, srcChainId: 1, tokenId: 123 });

      // Then
      expect(result).toEqual({
        addresses: {
          1: address,
        },
        uri: 'some/uri/123',
        tokenId: 123,
        name: 'Mock721',
        symbol: 'MNFT',
        type: TokenType.ERC721,
      });
      expect(readContract).toHaveBeenCalledTimes(3);
    });
  });
  describe('ERC1155', () => {
    const mockedMetadata = {
      description: 'Mock Description',
      external_url: 'https://example.com/mock-url',
      image: 'https://example.com/mock-image.png',
      name: 'Mock Meta Name',
    };

    const mockToken = customToken[1] as NFT;
    mockToken.metadata = mockedMetadata;

    it('should return correct token details for ERC1155 tokens', async () => {
      // Given
      const address: Address = zeroAddress;
      vi.mocked(detectContractType).mockResolvedValue(TokenType.ERC1155);
      vi.mocked(readContract)
        .mockResolvedValueOnce(mockToken.name)
        .mockResolvedValueOnce(mockToken.symbol)
        .mockResolvedValueOnce(mockToken.uri)
        .mockResolvedValueOnce(mockToken.balance);
      vi.mocked(fetchNFTMetadata).mockResolvedValue(mockedMetadata);

      // When
      const result = await getTokenWithInfoFromAddress({
        contractAddress: address,
        srcChainId: 1,
        tokenId: 123,
        owner: zeroAddress,
      });

      // Then
      expect(result).toEqual({
        addresses: {
          1: address,
        },
        uri: mockToken.uri,
        tokenId: mockToken.tokenId,
        name: mockToken.name,
        symbol: mockToken.symbol,
        balance: mockToken.balance,
        type: TokenType.ERC1155,
        metadata: mockedMetadata,
      });
    });

    it('should return correct token details for ERC1155 tokens with no owner passed', async () => {
      // Given
      const address: Address = zeroAddress;
      vi.mocked(detectContractType).mockResolvedValue(TokenType.ERC1155);
      vi.mocked(readContract)
        .mockResolvedValueOnce(mockToken.name)
        .mockResolvedValueOnce(mockToken.symbol)
        .mockResolvedValueOnce(mockToken.uri);

      vi.mocked(fetchNFTMetadata).mockResolvedValue(mockedMetadata);

      // When
      const result = await getTokenWithInfoFromAddress({ contractAddress: address, srcChainId: 1, tokenId: 123 });

      // Then
      expect(result).toEqual({
        addresses: {
          1: address,
        },
        uri: mockToken.uri,
        tokenId: mockToken.tokenId,
        name: mockToken.name,
        symbol: mockToken.symbol,
        balance: 0n,
        type: TokenType.ERC1155,
        metadata: mockedMetadata,
      });
    });

    it('should return correct token details for ERC1155 tokens with uri function req. tokenId', async () => {
      // Given
      const address: Address = zeroAddress;
      vi.mocked(detectContractType).mockResolvedValue(TokenType.ERC1155);
      vi.mocked(readContract)
        .mockResolvedValueOnce(mockToken.name)
        .mockResolvedValueOnce(mockToken.symbol)
        .mockResolvedValueOnce(null) // first uri call
        .mockResolvedValueOnce(mockToken.uri)
        .mockResolvedValueOnce(mockToken.balance);
      vi.mocked(fetchNFTMetadata).mockResolvedValue(mockedMetadata);

      // When
      const result = await getTokenWithInfoFromAddress({
        contractAddress: address,
        srcChainId: 1,
        tokenId: 123,
        owner: zeroAddress,
      });

      // Then
      expect(result).toEqual({
        addresses: {
          1: address,
        },
        uri: mockToken.uri,
        tokenId: mockToken.tokenId,
        name: mockToken.name,
        symbol: mockToken.symbol,
        balance: mockToken.balance,
        type: TokenType.ERC1155,
        metadata: mockedMetadata,
      });
    });
  });

  it('should throw for unknown token types', async () => {
    // Given
    const address: Address = zeroAddress;
    vi.mocked(detectContractType).mockRejectedValue(new UnknownTokenTypeError());

    // When
    try {
      await getTokenWithInfoFromAddress({ contractAddress: address, srcChainId: 1 });
      expect.fail('should have thrown');
    } catch (error) {
      expect(readContract).not.toHaveBeenCalled();
      expect(getToken).not.toHaveBeenCalled();
    }
  });
});
