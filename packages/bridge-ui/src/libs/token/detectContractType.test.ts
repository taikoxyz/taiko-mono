import { readContract } from '@wagmi/core';
import { zeroAddress } from 'viem';

import { UnknownTokenTypeError } from '$libs/error';

import { detectContractType } from './detectContractType';
import { TokenType } from './types';

vi.mock('@wagmi/core');

describe('detectContractType', () => {
  it('should return ERC721 for a valid ERC721 contract', async () => {
    // Given
    const contractAddress = zeroAddress;
    const chainId = 1;
    vi.mocked(readContract).mockImplementationOnce(() => Promise.resolve(true));

    // When
    const result = await detectContractType(contractAddress, chainId);

    // Then
    expect(result).toBe(TokenType.ERC721);
  });

  it('should return ERC1155 for a valid ERC1155 contract', async () => {
    // Given
    const contractAddress = zeroAddress;
    const chainId = 1;
    vi.mocked(readContract)
      .mockImplementationOnce(() => Promise.reject(false))
      .mockImplementationOnce(() => Promise.resolve(true));

    // When
    const result = await detectContractType(contractAddress, chainId);

    // Then
    expect(result).toBe(TokenType.ERC1155);
  });

  it('should return ERC20 for a valid ERC20 contract', async () => {
    // Given
    const contractAddress = zeroAddress;
    const chainId = 1;
    vi.mocked(readContract)
      .mockImplementationOnce(() => Promise.reject(new Error()))
      .mockImplementationOnce(() => Promise.reject(new Error()))
      .mockImplementationOnce(() => Promise.resolve());

    // When
    const result = await detectContractType(contractAddress, chainId);

    // Then
    expect(result).toBe(TokenType.ERC20);
  });

  it('should throw an error for an unknown contract type', async () => {
    // Given
    const contractAddress = zeroAddress;
    const chainId = 1;
    vi.mocked(readContract).mockImplementation(() => Promise.reject(UnknownTokenTypeError));

    // When & Then
    await expect(detectContractType(contractAddress, chainId)).rejects.toThrow(UnknownTokenTypeError);
  });

  it('should throw an error for if none of the checks passed', async () => {
    // Given
    const contractAddress = '0x1234567890abcdef1234567890abcdef12345678';
    const chainId = 1;
    vi.mocked(readContract)
      .mockImplementation(() => Promise.reject())
      .mockImplementation(() => Promise.reject())
      .mockImplementation(() => Promise.reject());

    // When & Then
    await expect(detectContractType(contractAddress, chainId)).rejects.toThrow(UnknownTokenTypeError);
  });
});
