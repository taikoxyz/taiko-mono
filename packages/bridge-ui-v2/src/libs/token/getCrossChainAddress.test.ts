import { getContract, type GetContractResult } from '@wagmi/core';
import { zeroAddress } from 'viem';

import { getCrossChainAddress } from './getCrossChainAddress';
import { type Token, TokenType } from './types';

vi.mock('@wagmi/core');
vi.mock('$abi');

const MockedETH: Token = {
  name: '',
  addresses: {},
  symbol: '',
  decimals: 0,
  type: TokenType.ETH,
};

const MockToken: Token = {
  name: 'MockToken',
  addresses: {
    1: '0x123456',
    2: '0x654321',
  },
  symbol: 'MOCK',
  decimals: 18,
  type: TokenType.ERC20,
};

const mockTokenVaultContract = {
  read: {
    canonicalToBridged: vi.fn(),
    isBridgedToken: vi.fn(),
    bridgedToCanonical: vi.fn(),
  },
} as unknown as GetContractResult<readonly unknown[], unknown>;

vi.mock('$libs/chain', () => ({
  chainContractsMap: {
    1: {
      tokenVaultAddress: '0x00001',
    },
    2: {
      tokenVaultAddress: '0x00002',
    },
  },
}));

describe('getCrossChainAddress', () => {
  const srcChainId = 1;
  const destChainId = 2;

  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(getContract).mockReturnValue(mockTokenVaultContract);
  });

  it('should return null for ETH type tokens', async () => {
    const result = await getCrossChainAddress({
      token: MockedETH,
      srcChainId: 1,
      destChainId: 2,
    });
    expect(result).toBeNull();
  });

  it('should return the bridged address of the token on the destination chain', async () => {
    // Given
    vi.mocked(mockTokenVaultContract.read.bridgedToCanonical).mockResolvedValue([
      destChainId,
      MockToken.addresses[destChainId],
    ]);
    vi.mocked(mockTokenVaultContract.read.canonicalToBridged).mockResolvedValue(MockToken.addresses[destChainId]);

    // When
    const result = await getCrossChainAddress({
      token: MockToken,
      srcChainId,
      destChainId,
    });

    // Then
    expect(result).toEqual(MockToken.addresses[destChainId]);
    expect(mockTokenVaultContract.read.bridgedToCanonical).toHaveBeenCalledWith([MockToken.addresses[srcChainId]]);
    expect(mockTokenVaultContract.read.canonicalToBridged).toHaveBeenCalledWith([
      BigInt(destChainId),
      MockToken.addresses[destChainId],
    ]);
  });

  it('should return 0x0 if the native token is not bridged yet on the destination chain', async () => {
    // Given
    vi.mocked(mockTokenVaultContract.read.bridgedToCanonical).mockResolvedValue([destChainId, zeroAddress]);
    vi.mocked(mockTokenVaultContract.read.canonicalToBridged).mockResolvedValue(zeroAddress);

    // When
    const result = await getCrossChainAddress({
      token: MockToken,
      srcChainId,
      destChainId,
    });

    // Then
    expect(result).toEqual(zeroAddress);
    expect(mockTokenVaultContract.read.bridgedToCanonical).toHaveBeenCalledWith([MockToken.addresses[srcChainId]]);
    expect(mockTokenVaultContract.read.canonicalToBridged).toHaveBeenCalledWith([
      BigInt(srcChainId),
      MockToken.addresses[srcChainId],
    ]);
  });

  it('should return 0x0 if the token itself is bridged, but not to the destination chain', async () => {
    // Given
    vi.mocked(mockTokenVaultContract.read.bridgedToCanonical).mockResolvedValue([
      destChainId,
      MockToken.addresses[srcChainId],
    ]);
    vi.mocked(mockTokenVaultContract.read.canonicalToBridged).mockResolvedValue(zeroAddress);

    // When
    const result = await getCrossChainAddress({
      token: MockToken,
      srcChainId,
      destChainId,
    });

    // Then
    expect(result).toEqual(zeroAddress);
    expect(mockTokenVaultContract.read.bridgedToCanonical).toHaveBeenCalledWith([MockToken.addresses[srcChainId]]);
    expect(mockTokenVaultContract.read.canonicalToBridged).toHaveBeenCalledWith([
      BigInt(destChainId),
      MockToken.addresses[srcChainId],
    ]);
  });
});
