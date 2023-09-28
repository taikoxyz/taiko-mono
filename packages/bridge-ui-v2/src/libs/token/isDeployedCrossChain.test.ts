import { getContract, type GetContractResult } from '@wagmi/core';
import { zeroAddress } from 'viem';

import { isDeployedCrossChain } from './isDeployedCrossChain';
import { type Token, TokenType } from './types';

vi.mock('@wagmi/core');
vi.mock('$abi');

let mockToken: Token;

const mockTokenVaultContract = {
  read: {
    canonicalToBridged: vi.fn(),
    isBridgedToken: vi.fn(),
    bridgedToCanonical: vi.fn(),
  },
} as unknown as GetContractResult<readonly unknown[], unknown>;

describe('isDeployedCrossChain', () => {
  const srcChainId = 1;
  const destChainId = 2;

  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(getContract).mockReturnValue(mockTokenVaultContract);
    mockToken = {
      name: 'MockToken',
      addresses: {
        1: '0x123456',
        2: '0x654321',
      },
      symbol: 'MOCK',
      decimals: 18,
      type: TokenType.ERC20,
    };
  });

  it('should return true if configured', async () => {
    // When
    const result = await isDeployedCrossChain({
      token: mockToken,
      srcChainId,
      destChainId,
    });

    // Then
    expect(result).toEqual(true);
  });

  it('should return false if not configured', async () => {
    mockToken.addresses[destChainId] = zeroAddress;
    // When
    const result = await isDeployedCrossChain({
      token: mockToken,
      srcChainId,
      destChainId,
    });

    // Then
    expect(result).toEqual(false);
  });
});
