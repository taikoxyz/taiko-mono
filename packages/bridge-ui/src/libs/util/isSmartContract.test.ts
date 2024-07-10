import { getPublicClient } from '@wagmi/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { config } from '$libs/wagmi';
import { L1_CHAIN_ID } from '$mocks';

import { isSmartContract } from './isSmartContract';

// Mock wagmi core
vi.mock('@wagmi/core');

vi.mock('$customToken');

vi.mock('$libs/token');

describe('isSmartContract', () => {
  const mockWalletAddress = '0x1234567890abcdef1234567890abcdef12345678';
  const mockChainId = L1_CHAIN_ID;
  const mockClient = {
    getBytecode: vi.fn(),
  };

  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(getPublicClient).mockReturnValue(mockClient);
  });

  it('should return true if bytecode exists', async () => {
    // Given
    mockClient.getBytecode.mockResolvedValueOnce('0x6000600055');

    // When
    const result = await isSmartContract(mockWalletAddress, mockChainId);

    // Then
    expect(result).toBe(true);
    expect(getPublicClient).toHaveBeenCalledWith(config, { chainId: mockChainId });
    expect(mockClient.getBytecode).toHaveBeenCalledWith({ address: mockWalletAddress });
  });

  it('should return false if bytecode does not exist', async () => {
    // Given
    mockClient.getBytecode.mockResolvedValueOnce('0x');

    // When
    const result = await isSmartContract(mockWalletAddress, mockChainId);

    // Then
    expect(result).toBe(false);
    expect(getPublicClient).toHaveBeenCalledWith(config, { chainId: mockChainId });
    expect(mockClient.getBytecode).toHaveBeenCalledWith({ address: mockWalletAddress });
  });

  it('should throw an error if no public client found', async () => {
    // Given
    vi.mocked(getPublicClient).mockReturnValueOnce(null);

    // When/Then
    await expect(isSmartContract(mockWalletAddress, mockChainId)).rejects.toThrow('No public client found');
  });
});
