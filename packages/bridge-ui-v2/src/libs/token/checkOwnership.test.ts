import { readContract } from '@wagmi/core';

import { checkOwnership } from './checkOwnership';
import { detectContractType } from './detectContractType';
import { TokenType } from './types';

vi.mock('@wagmi/core');

vi.mock('./detectContractType', () => {
  const actual = vi.importActual('./detectContractType');
  return {
    ...actual,
    detectContractType: vi.fn(),
  };
});
describe('checkOwnership', () => {
  const OWNER = '0x1';
  const TOKEN_ADDRESS = '0x2';
  const TOKEN_IDS = [1, 2];
  const CHAIN_ID = 1;

  afterEach(() => {
    vi.clearAllMocks();
    vi.resetAllMocks();
  });

  describe('ERC1155', () => {
    it('should return the correct result if the account owns all the tokens', async () => {
      // Given
      vi.mocked(readContract).mockResolvedValueOnce(BigInt(10)).mockResolvedValueOnce(BigInt(10));

      // When
      const result = await checkOwnership(TOKEN_ADDRESS, TokenType.ERC1155, TOKEN_IDS, OWNER, CHAIN_ID);

      // Then
      expect(result).toEqual([
        { tokenId: TOKEN_IDS[0], isOwner: true },
        { tokenId: TOKEN_IDS[1], isOwner: true },
      ]);
    });

    it('should return the correct result if a single token is passed and the account owns it', async () => {
      // Given
      vi.mocked(readContract).mockResolvedValueOnce(BigInt(10)).mockResolvedValueOnce(BigInt(10));

      // When
      const result = await checkOwnership(TOKEN_ADDRESS, TokenType.ERC1155, TOKEN_IDS[0], OWNER, CHAIN_ID);

      // Then
      expect(result).toEqual([{ tokenId: TOKEN_IDS[0], isOwner: true }]);
    });

    it('should return the correct result if the account does not own any of the tokens', async () => {
      // Given
      vi.mocked(readContract).mockResolvedValueOnce(BigInt(0)).mockResolvedValueOnce(BigInt(0));

      // When
      const result = await checkOwnership(TOKEN_ADDRESS, TokenType.ERC1155, TOKEN_IDS, OWNER, CHAIN_ID);

      // Then
      expect(result).toEqual([
        { tokenId: TOKEN_IDS[0], isOwner: false },
        { tokenId: TOKEN_IDS[1], isOwner: false },
      ]);
    });

    it('should return the correct result if the account only owns some of the tokens', async () => {
      // Given
      vi.mocked(readContract).mockResolvedValueOnce(BigInt(10)).mockResolvedValueOnce(BigInt(0));

      // When
      const result = await checkOwnership(TOKEN_ADDRESS, TokenType.ERC1155, TOKEN_IDS, OWNER, CHAIN_ID);

      // Then
      expect(result).toEqual([
        { tokenId: TOKEN_IDS[0], isOwner: true },
        { tokenId: TOKEN_IDS[1], isOwner: false },
      ]);
    });

    it('should return the correct result if a single token is passed and the account does not own it', async () => {
      // Given
      vi.mocked(readContract).mockResolvedValueOnce(BigInt(0)).mockResolvedValueOnce(BigInt(0));

      // When
      const result = await checkOwnership(TOKEN_ADDRESS, TokenType.ERC1155, TOKEN_IDS[0], OWNER, CHAIN_ID);

      // Then
      expect(result).toEqual([{ tokenId: TOKEN_IDS[0], isOwner: false }]);
    });

    it('should return the correct result if the account does not own any of the tokens ', async () => {
      // Given
      vi.mocked(readContract).mockResolvedValueOnce(BigInt(0)).mockResolvedValueOnce(BigInt(0));

      // When
      const result = await checkOwnership(TOKEN_ADDRESS, TokenType.ERC1155, TOKEN_IDS, OWNER, CHAIN_ID);

      // Then
      expect(result).toEqual([
        { tokenId: TOKEN_IDS[0], isOwner: false },
        { tokenId: TOKEN_IDS[1], isOwner: false },
      ]);
    });
  });

  describe('ERC721', () => {
    it('should return true if the account owns all the tokens', async () => {
      // Given
      vi.mocked(readContract).mockResolvedValueOnce(OWNER).mockResolvedValueOnce(OWNER);

      // When
      const result = await checkOwnership(TOKEN_ADDRESS, TokenType.ERC721, TOKEN_IDS, OWNER, CHAIN_ID);

      // Then
      expect(result).toEqual([
        { tokenId: TOKEN_IDS[0], isOwner: true },
        { tokenId: TOKEN_IDS[1], isOwner: true },
      ]);
    });

    it('should return the correct result if the account owns all the tokens (no token type passed)', async () => {
      // Given
      vi.mocked(readContract).mockResolvedValueOnce(OWNER).mockResolvedValueOnce(OWNER);

      vi.mocked(detectContractType).mockResolvedValueOnce(TokenType.ERC721);

      // When
      const result = await checkOwnership(TOKEN_ADDRESS, null, TOKEN_IDS, OWNER, CHAIN_ID);

      // Then
      expect(result).toEqual([
        { tokenId: TOKEN_IDS[0], isOwner: true },
        { tokenId: TOKEN_IDS[1], isOwner: true },
      ]);
    });

    it('should return the correct result if a single token is passed and the account owns it', async () => {
      // Given
      vi.mocked(readContract).mockResolvedValueOnce(OWNER);

      // When
      const result = await checkOwnership(TOKEN_ADDRESS, TokenType.ERC721, TOKEN_IDS[0], OWNER, CHAIN_ID);

      // Then
      expect(result).toEqual([{ tokenId: TOKEN_IDS[0], isOwner: true }]);
    });

    it('should return correct result if the account does not own any of the tokens', async () => {
      // Given
      vi.mocked(readContract).mockResolvedValueOnce('0x2').mockResolvedValueOnce('0x3');

      // When
      const result = await checkOwnership(TOKEN_ADDRESS, TokenType.ERC721, TOKEN_IDS, OWNER, CHAIN_ID);

      // Then
      expect(result).toEqual([
        { tokenId: TOKEN_IDS[0], isOwner: false },
        { tokenId: TOKEN_IDS[1], isOwner: false },
      ]);
    });

    it('should return the correct result if the account only owns some of the tokens', async () => {
      // Given
      vi.mocked(readContract).mockResolvedValueOnce(OWNER).mockResolvedValueOnce('0x3');

      // When
      const result = await checkOwnership(TOKEN_ADDRESS, TokenType.ERC721, TOKEN_IDS, OWNER, CHAIN_ID);

      // Then
      expect(result).toEqual([
        { tokenId: TOKEN_IDS[0], isOwner: true },
        { tokenId: TOKEN_IDS[1], isOwner: false },
      ]);
    });

    it('should return the correct result if a single token is passed and the account does not own it', async () => {
      // Given
      vi.mocked(readContract).mockResolvedValueOnce('0x2').mockResolvedValueOnce('0x3');

      // When
      const result = await checkOwnership(TOKEN_ADDRESS, TokenType.ERC721, TOKEN_IDS[0], OWNER, CHAIN_ID);

      // Then
      expect(result).toEqual([{ tokenId: TOKEN_IDS[0], isOwner: false }]);
    });
  });

  describe('General tests', () => {
    it('should return an empty array if tokenType is null', async () => {
      // When
      const result = await checkOwnership(TOKEN_ADDRESS, null, TOKEN_IDS, OWNER, CHAIN_ID);

      // Then
      expect(result).toEqual([]);
    });

    it('should return an empty array if tokenIds array is empty', async () => {
      // When
      const result = await checkOwnership(TOKEN_ADDRESS, TokenType.ERC721, [], OWNER, CHAIN_ID);

      // Then
      expect(result).toEqual([]);
    });
  });
});
