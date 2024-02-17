import { readContract } from '@wagmi/core';
import { get } from 'svelte/store';

import { bridgePausedModal } from '$stores/modal';

import { checkForPausedContracts } from './checkForPausedContracts';

vi.mock('@wagmi/core');
vi.mock('viem');

vi.mock('$bridgeConfig', () => ({
  routingContractsMap: {
    1: {
      2: {
        erc20VaultAddress: '0x00001',
        bridgeAddress: '0x00002',
        erc721VaultAddress: '0x00003',
        erc1155VaultAddress: '0x00004',
        crossChainSyncAddress: '0x00005',
        signalServiceAddress: '0x00006',
      },
    },
    2: {
      1: {
        erc20VaultAddress: '0x00007',
        bridgeAddress: '0x00008',
        erc721VaultAddress: '0x00009',
        erc1155VaultAddress: '0x00010',
        crossChainSyncAddress: '0x00011',
        signalServiceAddress: '0x00012',
      },
    },
    3: {
      2: {
        erc20VaultAddress: '0x00007',
        bridgeAddress: '0x00008',
        erc721VaultAddress: '0x00009',
        erc1155VaultAddress: '0x00010',
        crossChainSyncAddress: '0x00011',
        signalServiceAddress: '0x00012',
      },
    },
  },
}));

describe('checkForPausedContracts', () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  test('should return false if no contracts are paused', async () => {
    // when
    await checkForPausedContracts();

    // then
    expect(readContract).toHaveBeenCalledTimes(3);
    expect(get(bridgePausedModal)).toBe(false);
  });

  test('should return true if at least one contract is paused', async () => {
    // given
    vi.mocked(readContract).mockResolvedValueOnce(true);

    // when
    await checkForPausedContracts();

    // then
    expect(readContract).toHaveBeenCalledTimes(3);
    expect(get(bridgePausedModal)).toBe(true);
  });

  test('should handle errors', async () => {
    // given
    vi.mocked(readContract).mockRejectedValueOnce(new Error('some error'));

    // when
    await checkForPausedContracts();

    // then
    expect(get(bridgePausedModal)).toBe(true);
    expect(readContract).toHaveBeenCalledTimes(3);
  });
});
