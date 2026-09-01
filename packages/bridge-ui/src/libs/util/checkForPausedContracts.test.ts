import { readContract } from '@wagmi/core';
import { get } from 'svelte/store';

import { bridgePausedModal } from '$stores/modal';

import { checkForPausedContracts } from './checkForPausedContracts';

vi.mock('@wagmi/core');
vi.mock('viem');

vi.mock('$bridgeConfig', () => ({
  routingContractsMap: {
    // Two destinations sharing one bridge, which is how a real multi-chain config looks
    1: {
      2: { bridgeAddress: '0x00002' },
      3: { bridgeAddress: '0x00002' },
    },
    2: {
      1: { bridgeAddress: '0x00008' },
    },
    3: {
      2: { bridgeAddress: '0x00018' },
    },
  },
}));

const chainOf = (call: unknown[]) => (call[1] as { chainId: number }).chainId;

describe('checkForPausedContracts', () => {
  beforeEach(() => {
    vi.resetAllMocks();
    bridgePausedModal.set(false);
  });

  test('reads each configured bridge once, not once per destination', async () => {
    expect(await checkForPausedContracts()).toBe(false);

    expect(readContract).toHaveBeenCalledTimes(3);
    expect(vi.mocked(readContract).mock.calls.map(chainOf).sort()).toEqual([1, 2, 3]);
    expect(get(bridgePausedModal)).toBe(false);
  });

  test('reports paused when at least one contract is paused', async () => {
    vi.mocked(readContract).mockResolvedValueOnce(true);

    expect(await checkForPausedContracts()).toBe(true);
    expect(get(bridgePausedModal)).toBe(true);
  });

  test('reads only the given source chain when one is passed', async () => {
    expect(await checkForPausedContracts(2)).toBe(false);

    expect(readContract).toHaveBeenCalledTimes(1);
    expect(chainOf(vi.mocked(readContract).mock.calls[0])).toBe(2);
  });

  test('a chain that cannot be read does not make the bridge paused', async () => {
    // The other two answer normally, so an unreachable RPC on one chain used to be the
    // difference between bridging and a "bridge is paused" modal
    vi.mocked(readContract).mockRejectedValueOnce(new Error('some error'));

    expect(await checkForPausedContracts()).toBe(false);
    expect(get(bridgePausedModal)).toBe(false);
  });

  test('a chain that cannot be read still yields to one that reports paused', async () => {
    vi.mocked(readContract).mockRejectedValueOnce(new Error('some error')).mockResolvedValueOnce(true);

    expect(await checkForPausedContracts()).toBe(true);
    expect(get(bridgePausedModal)).toBe(true);
  });

  test('does not dismiss a known pause because the other chains answered', async () => {
    // The unreadable chain might be the paused one. Clearing the modal on the strength of
    // the chains that did answer asserts something no read established
    bridgePausedModal.set(true);
    vi.mocked(readContract).mockRejectedValueOnce(new Error('rpc down'));

    expect(await checkForPausedContracts()).toBe(false);
    expect(get(bridgePausedModal)).toBe(true);
  });

  test('clears the modal once every chain answers', async () => {
    bridgePausedModal.set(true);
    vi.mocked(readContract).mockResolvedValue(false);

    expect(await checkForPausedContracts()).toBe(false);
    expect(get(bridgePausedModal)).toBe(false);
  });

  test('leaves a known pause standing when nothing can be read', async () => {
    bridgePausedModal.set(true);
    vi.mocked(readContract).mockRejectedValue(new Error('rpc down'));

    // No verdict either way: the modal must not be dismissed by an outage
    expect(await checkForPausedContracts()).toBe(false);
    expect(get(bridgePausedModal)).toBe(true);
  });
});
