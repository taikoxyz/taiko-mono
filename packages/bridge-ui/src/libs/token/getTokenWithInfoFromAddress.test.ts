import { createConfig, getToken, type GetTokenReturnType, readContract } from '@wagmi/core';
import { type Address, zeroAddress } from 'viem';

import { UnknownTokenTypeError } from '$libs/error';
import { config } from '$libs/wagmi';
import { L1_CHAIN_ID, MOCK_ERC20, MOCK_ERC721, MOCK_ERC1155, MOCK_METADATA } from '$mocks';

import { detectContractType } from './detectContractType';
import { fetchNFTMetadata } from './fetchNFTMetadata';
import { getTokenWithInfoFromAddress } from './getTokenWithInfoFromAddress';
import { TokenType } from './types';

vi.mock('@wagmi/core');
vi.mock('./fetchNFTMetadata');
vi.mock('$libs/wagmi/client');

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
      const address: Address = MOCK_ERC20.addresses[L1_CHAIN_ID];
      vi.mocked(detectContractType).mockResolvedValue(TokenType.ERC20);
      vi.mocked(getToken).mockResolvedValue({
        name: MOCK_ERC20.name,
        symbol: MOCK_ERC20.symbol,
        decimals: MOCK_ERC20.decimals,
      } as GetTokenReturnType);

      // When
      const result = await getTokenWithInfoFromAddress({ contractAddress: address, srcChainId: L1_CHAIN_ID });

      // Then
      expect(result).toEqual({ ...MOCK_ERC20, addresses: { [L1_CHAIN_ID]: address } });

      expect(getToken).toHaveBeenCalledOnce();
      expect(getToken).toHaveBeenCalledWith(config, {
        address,
        chainId: L1_CHAIN_ID,
      });
    });
  });

  describe('ERC721', () => {
    it('should return correct token details for ERC721 tokens', async () => {
      // Given
      const address: Address = MOCK_ERC721.addresses[L1_CHAIN_ID];
      vi.mocked(createConfig);
      vi.mocked(detectContractType).mockResolvedValue(TokenType.ERC721);
      vi.mocked(readContract)
        .mockResolvedValueOnce(MOCK_ERC721.name)
        .mockResolvedValueOnce(MOCK_ERC721.symbol)
        .mockResolvedValueOnce(MOCK_ERC721.uri);
      vi.mocked(fetchNFTMetadata).mockResolvedValue(MOCK_METADATA);

      // When
      const result = await getTokenWithInfoFromAddress({
        contractAddress: address,
        srcChainId: L1_CHAIN_ID,
        tokenId: MOCK_ERC721.tokenId,
      });

      // Then
      expect(result).toEqual({ ...MOCK_ERC721, addresses: { [L1_CHAIN_ID]: address } });
      expect(readContract).toHaveBeenCalledTimes(3);
    });
  });
  describe('ERC1155', () => {
    it('should return correct token details for ERC1155 tokens', async () => {
      // Given
      const address: Address = MOCK_ERC1155.addresses[L1_CHAIN_ID];
      vi.mocked(detectContractType).mockResolvedValue(TokenType.ERC1155);
      vi.mocked(readContract)
        .mockResolvedValueOnce(MOCK_ERC1155.name)
        .mockResolvedValueOnce(MOCK_ERC1155.symbol)
        .mockResolvedValueOnce(MOCK_ERC1155.uri)
        .mockResolvedValueOnce(MOCK_ERC1155.balance);
      vi.mocked(fetchNFTMetadata).mockResolvedValue(MOCK_METADATA);

      // When
      const result = await getTokenWithInfoFromAddress({
        contractAddress: address,
        srcChainId: L1_CHAIN_ID,
        tokenId: MOCK_ERC1155.tokenId,
        owner: zeroAddress,
      });

      // Then
      expect(result).toEqual({ ...MOCK_ERC1155, addresses: { [L1_CHAIN_ID]: address } });
    });

    it('should return correct token details for ERC1155 tokens with no owner passed', async () => {
      // Given
      const address: Address = MOCK_ERC1155.addresses[L1_CHAIN_ID];
      vi.mocked(detectContractType).mockResolvedValue(TokenType.ERC1155);
      vi.mocked(readContract)
        .mockResolvedValueOnce(MOCK_ERC1155.name)
        .mockResolvedValueOnce(MOCK_ERC1155.symbol)
        .mockResolvedValueOnce(MOCK_ERC1155.uri);
      vi.mocked(fetchNFTMetadata).mockResolvedValue(MOCK_METADATA);

      // When
      const result = await getTokenWithInfoFromAddress({
        contractAddress: address,
        srcChainId: L1_CHAIN_ID,
        tokenId: MOCK_ERC1155.tokenId,
      });

      // Then
      expect(result).toEqual({ ...MOCK_ERC1155, addresses: { [L1_CHAIN_ID]: address }, balance: 0n });
    });

    it('should return correct token details for ERC1155 tokens with uri function req. tokenId', async () => {
      // Given
      const address: Address = MOCK_ERC1155.addresses[L1_CHAIN_ID];
      vi.mocked(detectContractType).mockResolvedValue(TokenType.ERC1155);
      vi.mocked(readContract)
        .mockResolvedValueOnce(MOCK_ERC1155.name)
        .mockResolvedValueOnce(MOCK_ERC1155.symbol)
        .mockResolvedValueOnce(null) // first uri call
        .mockResolvedValueOnce(MOCK_ERC1155.uri)
        .mockResolvedValueOnce(MOCK_ERC1155.balance);
      vi.mocked(fetchNFTMetadata).mockResolvedValue(MOCK_METADATA);

      // When
      const result = await getTokenWithInfoFromAddress({
        contractAddress: address,
        srcChainId: L1_CHAIN_ID,
        tokenId: MOCK_ERC1155.tokenId,
        owner: zeroAddress,
      });

      // Then
      expect(result).toEqual({ ...MOCK_ERC1155, addresses: { [L1_CHAIN_ID]: address } });
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
