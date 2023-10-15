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

  it('should return true if the account owns all the tokens (ERC1155)', async () => {
    // Given
    vi.mocked(readContract).mockResolvedValueOnce(BigInt(10)).mockResolvedValueOnce(BigInt(10));

    // When
    const result = await checkOwnership(TOKEN_ADDRESS, TokenType.ERC1155, TOKEN_IDS, OWNER, CHAIN_ID);

    // Then
    expect(result).toBe(true);
  });

  it('should return false if the account does not own any of the tokens (ERC1155)', async () => {
    // Given
    vi.mocked(readContract).mockResolvedValueOnce(BigInt(0)).mockResolvedValueOnce(BigInt(0));

    // When
    const result = await checkOwnership(TOKEN_ADDRESS, TokenType.ERC1155, TOKEN_IDS, OWNER, CHAIN_ID);

    // Then
    expect(result).toBe(false);
  });

  it('should return true if the account owns all the tokens (ERC721)', async () => {
    // Given
    vi.mocked(readContract).mockResolvedValueOnce(OWNER).mockResolvedValueOnce(OWNER);

    // When
    const result = await checkOwnership(TOKEN_ADDRESS, TokenType.ERC721, TOKEN_IDS, OWNER, CHAIN_ID);

    // Then
    expect(result).toBe(true);
  });

  it('should return true if the account owns all the tokens (no token type passed)', async () => {
    // Given
    vi.mocked(readContract).mockResolvedValueOnce(OWNER).mockResolvedValueOnce(OWNER);

    vi.mocked(detectContractType).mockResolvedValueOnce(TokenType.ERC721);

    // When
    const result = await checkOwnership(TOKEN_ADDRESS, null, TOKEN_IDS, OWNER, CHAIN_ID);

    // Then
    expect(result).toBe(true);
  });

  it('should return false if the account does not own any of the tokens (ERC721)', async () => {
    // Given
    vi.mocked(readContract).mockResolvedValueOnce('0x2').mockResolvedValueOnce('0x3');

    // When
    const result = await checkOwnership(TOKEN_ADDRESS, TokenType.ERC721, TOKEN_IDS, OWNER, CHAIN_ID);

    // Then
    expect(result).toBe(false);
  });

  it('should return false if tokenType is null', async () => {
    // When
    const result = await checkOwnership(TOKEN_ADDRESS, null, TOKEN_IDS, OWNER, CHAIN_ID);

    // Then
    expect(result).toBe(false);
  });

  it('should return false if tokenIds array is empty', async () => {
    // When
    const result = await checkOwnership(TOKEN_ADDRESS, TokenType.ERC721, [], OWNER, CHAIN_ID);

    // Then
    expect(result).toBe(false);
  });
});
