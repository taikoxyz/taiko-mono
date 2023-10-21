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

let mockToken: Token;

const mockTokenVaultContract = {
  read: {
    canonicalToBridged: vi.fn(),
    isBridgedToken: vi.fn(),
    bridgedToCanonical: vi.fn(),
  },
} as unknown as GetContractResult<readonly unknown[], unknown>;

vi.mock('$bridgeConfig', () => ({
  routingContractsMap: {
    1: {
      2: {
        erc20VaultAddress: '0x00001',
      },
    },
    2: {
      1: {
        erc20VaultAddress: '0x00002',
      },
    },
  },
}));

describe('getCrossChainAddress', () => {
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

  it('should return null for ETH type tokens', async () => {
    const result = await getCrossChainAddress({
      token: MockedETH,
      srcChainId: 1,
      destChainId: 2,
    });
    expect(result).toBeNull();
  });

  it('should return the bridged address of the token on the destination chain if not already stored', async () => {
    // Given
    vi.mocked(mockTokenVaultContract.read.bridgedToCanonical).mockResolvedValue([
      destChainId,
      mockToken.addresses[destChainId],
    ]);
    vi.mocked(mockTokenVaultContract.read.canonicalToBridged).mockResolvedValue(mockToken.addresses[destChainId]);

    // temporarily store the mocked address so we do not have to hardcode variables
    const preconfiguredAddress = mockToken.addresses[destChainId];

    // set the destination address it to zero so we can test it
    mockToken.addresses[destChainId] = zeroAddress;

    // When
    const result = await getCrossChainAddress({
      token: mockToken,
      srcChainId,
      destChainId,
    });

    // Then
    expect(result).toEqual(preconfiguredAddress);
    expect(mockTokenVaultContract.read.bridgedToCanonical).toHaveBeenCalledWith([mockToken.addresses[srcChainId]]);
    expect(mockTokenVaultContract.read.canonicalToBridged).toHaveBeenCalledWith([
      BigInt(destChainId),
      preconfiguredAddress,
    ]);
  });

  it('should return the bridged address if stored or configured', async () => {
    // When
    const result = await getCrossChainAddress({
      token: mockToken,
      srcChainId,
      destChainId,
    });

    // Then
    expect(result).toEqual(mockToken.addresses[destChainId]);
    expect(mockTokenVaultContract.read.bridgedToCanonical).not.toHaveBeenCalled();
    expect(mockTokenVaultContract.read.canonicalToBridged).not.toHaveBeenCalled();
  });

  it('should return 0x0 if the native token is not bridged yet on the destination chain', async () => {
    // Given
    vi.mocked(mockTokenVaultContract.read.bridgedToCanonical).mockResolvedValue([destChainId, zeroAddress]);
    vi.mocked(mockTokenVaultContract.read.canonicalToBridged).mockResolvedValue(zeroAddress);
    // set the destination address it to zero so we can test it
    mockToken.addresses[destChainId] = zeroAddress;

    // When
    const result = await getCrossChainAddress({
      token: mockToken,
      srcChainId,
      destChainId,
    });

    // Then
    expect(result).toEqual(zeroAddress);
    expect(mockTokenVaultContract.read.bridgedToCanonical).toHaveBeenCalledWith([mockToken.addresses[srcChainId]]);
    expect(mockTokenVaultContract.read.canonicalToBridged).toHaveBeenCalledWith([
      BigInt(srcChainId),
      mockToken.addresses[srcChainId],
    ]);
  });

  it('should return 0x0 if the token itself is bridged, but not to the destination chain', async () => {
    // Given
    vi.mocked(mockTokenVaultContract.read.bridgedToCanonical).mockResolvedValue([
      destChainId,
      mockToken.addresses[srcChainId],
    ]);
    vi.mocked(mockTokenVaultContract.read.canonicalToBridged).mockResolvedValue(zeroAddress);

    // set the destination address it to zero so we can test it
    mockToken.addresses[destChainId] = zeroAddress;

    // When
    const result = await getCrossChainAddress({
      token: mockToken,
      srcChainId,
      destChainId,
    });

    // Then
    expect(result).toEqual(zeroAddress);
    expect(mockTokenVaultContract.read.bridgedToCanonical).toHaveBeenCalledWith([mockToken.addresses[srcChainId]]);
    expect(mockTokenVaultContract.read.canonicalToBridged).toHaveBeenCalledWith([
      BigInt(destChainId),
      mockToken.addresses[srcChainId],
    ]);
  });
});
