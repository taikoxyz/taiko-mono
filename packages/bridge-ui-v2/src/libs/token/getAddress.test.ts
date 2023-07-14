import { getContract, type GetContractResult } from '@wagmi/core';
import { zeroAddress } from 'viem';

import { getAddress } from './getAddress';
import type { Token } from './types';

vi.mock('@wagmi/core', () => ({
  getContract: vi.fn(),
}));

vi.mock('$libs/chain', () => ({
  chainContractsMap: {
    2: {
      tokenVaultAddress: '0x123',
    },
  },
}));

vi.mock('$abi', () => ({
  tokenVaultABI: [],
}));

const mockETH = {
  symbol: 'ETH',
  addresses: {
    1: zeroAddress,
    2: zeroAddress,
  },
} as unknown as Token;

const mockERC20 = {
  symbol: 'MKT',
  addresses: {
    1: '0x123',
    2: zeroAddress,
  },
} as unknown as Token;

const mockTokenContract = {
  read: {
    canonicalToBridged: vi.fn(),
  },
} as unknown as GetContractResult<readonly unknown[], unknown>;

describe('getAddress', () => {
  beforeAll(() => {
    vi.mocked(getContract).mockReturnValue(mockTokenContract);
  });

  it('should return undefined if no source chain id is passed in', async () => {
    expect(await getAddress(mockETH)).toBeUndefined();
  });

  it('should return the address if ETH', async () => {
    expect(await getAddress(mockETH, 1)).toEqual(zeroAddress);
  });

  it('should return the address if ERC20 and has address on the source chain', async () => {
    expect(await getAddress(mockERC20, 1)).toEqual('0x123');
  });

  it('should return undefined if ERC20 and has no address on the source chain and no destination chain is is passed in', async () => {
    const copyMockERC20 = JSON.parse(JSON.stringify(mockERC20));
    copyMockERC20.addresses[1] = zeroAddress;
    expect(await getAddress(copyMockERC20, 1)).toBeUndefined();
  });

  it('should return the address of deployed ERC20 token', async () => {
    vi.mocked(mockTokenContract.read.canonicalToBridged).mockResolvedValue('0x456');

    expect(await getAddress(mockERC20, 2, 1)).toEqual('0x456');
    expect(mockTokenContract.read.canonicalToBridged).toHaveBeenCalledWith([BigInt(1), '0x123']);
    expect(getContract).toHaveBeenCalledWith({
      abi: [],
      address: '0x123',
    });
  });
});
