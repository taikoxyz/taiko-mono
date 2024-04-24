import { zeroAddress } from 'viem';

import { ETHToken } from '$libs/token';
import { L1_CHAIN_ID, MOCK_ERC20, MOCK_ERC721, MOCK_ERC1155 } from '$mocks';

import { calculateMessageDataSize } from './calculateMessageDataSize';

vi.mock('../../generated/customTokenConfig', () => {
  const mockERC20 = {
    name: 'MockERC20',
    addresses: { 1: zeroAddress },
    symbol: 'MOCK',
    decimals: 18,
    type: 'ERC20',
  };
  return {
    customToken: [mockERC20],
  };
});

describe('calculateMessageDataSize', () => {
  it('should calculate the message data size for ERC20 correctly', async () => {
    // Given
    const token = MOCK_ERC20;
    const chainId = L1_CHAIN_ID;
    const expectedSize = { size: 516 };

    // When
    const result = await calculateMessageDataSize({ token, chainId });

    // Then
    expect(result).toEqual(expectedSize);
  });

  it('should calculate the message data size for ETH correctly', async () => {
    // Given
    const token = ETHToken;
    const chainId = L1_CHAIN_ID;
    const expectedSize = { size: 0 };

    // When
    const result = await calculateMessageDataSize({ token, chainId });

    expect(result).toEqual(expectedSize);
  });

  it('should calculate the message data size for ERC721 correctly', async () => {
    // Given
    const token = MOCK_ERC721;
    const chainId = L1_CHAIN_ID;
    const expectedSize = { size: 548 };

    // When
    const result = await calculateMessageDataSize({
      token,
      chainId,
      tokenIds: [1],
    });

    // Then
    expect(result).toEqual(expectedSize);
  });

  it('should calculate the message data size for multiple ERC721 correctly', async () => {
    // Given
    const token = MOCK_ERC721;
    const chainId = L1_CHAIN_ID;
    const expectedSize = { size: 612 };

    // When
    const result = await calculateMessageDataSize({
      token,
      chainId,
      tokenIds: [1, 2, 3],
    });

    // Then
    expect(result).toEqual(expectedSize);
  });

  it('should calculate the message data size for multiple ERC1155 correctly', async () => {
    // Given
    const token = MOCK_ERC1155;
    const chainId = L1_CHAIN_ID;
    const expectedSize = { size: 772 };

    // When
    const result = await calculateMessageDataSize({
      token,
      chainId,
      tokenIds: [1, 2, 3],
      amounts: [5, 1, 42],
    });

    // Then
    expect(result).toEqual(expectedSize);
  });
});
