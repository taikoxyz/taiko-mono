/**
 * The claim UI keys off this answer, so "the destination chain has not synced this block yet"
 * and "we could not find out" must not be the same value. They used to both be `false`, which
 * is why the zero-fee manual claim entry was offered on transactions whose claim BridgeProver
 * was certain to reject.
 */
import { getPublicClient, readContract } from '@wagmi/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('$libs/chain', () => ({ isL2Chain: (chainId: number) => chainId === 2 }));
vi.mock('$libs/wagmi', () => ({ config: {} }));

import { isTransactionProcessable } from './isTransactionProcessable';
import { type BridgeTransaction, MessageStatus } from './types';

// 10867665 - the block a message was sent in, in the shape a relayer row carries it
const SENT_AT = '0xa5d3d1';

const l2ToL1 = (overrides: Partial<BridgeTransaction> = {}) =>
  ({
    srcChainId: 2n,
    destChainId: 1n,
    msgStatus: MessageStatus.NEW,
    message: { id: 1n },
    blockNumber: SENT_AT,
    ...overrides,
  }) as unknown as BridgeTransaction;

const l1ToL2 = (overrides: Partial<BridgeTransaction> = {}) =>
  ({
    srcChainId: 1n,
    destChainId: 2n,
    msgStatus: MessageStatus.NEW,
    message: { id: 1n },
    blockNumber: SENT_AT,
    ...overrides,
  }) as unknown as BridgeTransaction;

/** A destination-chain client whose last CheckpointSaved names `checkpoint` */
const clientWithCheckpoints = (checkpoints: bigint[]) => ({
  getBlockNumber: vi.fn().mockResolvedValue(25_889_060n),
  getContractEvents: vi.fn().mockResolvedValue(checkpoints.map((blockNumber) => ({ args: { blockNumber } }))),
});

beforeEach(() => {
  vi.mocked(getPublicClient).mockReset();
  vi.mocked(readContract).mockReset();
});

describe('isTransactionProcessable', () => {
  it('is true once the message has left NEW, without reading any chain', async () => {
    await expect(isTransactionProcessable(l2ToL1({ msgStatus: MessageStatus.DONE }))).resolves.toBe(true);
    expect(getPublicClient).not.toHaveBeenCalled();
  });

  it('is false when there is no message body to claim', async () => {
    // Not an unknown: every claim path throws on a missing message, so no entry may be offered
    await expect(isTransactionProcessable(l2ToL1({ message: undefined }))).resolves.toBe(false);
  });

  it('is null when the transaction carries no source block to compare against', async () => {
    await expect(isTransactionProcessable(l2ToL1({ blockNumber: undefined }))).resolves.toBe(null);
  });

  describe('L2 to L1', () => {
    it('is false when the latest checkpoint is behind the block the message was sent in', async () => {
      vi.mocked(getPublicClient).mockReturnValue(clientWithCheckpoints([10_866_581n, 10_867_539n]) as never);

      await expect(isTransactionProcessable(l2ToL1())).resolves.toBe(false);
    });

    it('is true once a checkpoint covers the block the message was sent in', async () => {
      vi.mocked(getPublicClient).mockReturnValue(clientWithCheckpoints([10_867_539n, 10_868_490n]) as never);

      await expect(isTransactionProcessable(l2ToL1())).resolves.toBe(true);
    });

    it('is null when the search window holds no checkpoint at all', async () => {
      vi.mocked(getPublicClient).mockReturnValue(clientWithCheckpoints([]) as never);

      await expect(isTransactionProcessable(l2ToL1())).resolves.toBe(null);
    });

    it('is null when the checkpoint read fails', async () => {
      const client = clientWithCheckpoints([]);
      client.getContractEvents.mockRejectedValue(new Error('rate limited'));
      vi.mocked(getPublicClient).mockReturnValue(client as never);

      await expect(isTransactionProcessable(l2ToL1())).resolves.toBe(null);
    });

    it('is null when there is no client for the destination chain', async () => {
      vi.mocked(getPublicClient).mockReturnValue(undefined as never);

      await expect(isTransactionProcessable(l2ToL1())).resolves.toBe(null);
    });

    it('falls back to the receipt when the row was never given a block number', async () => {
      vi.mocked(getPublicClient).mockReturnValue(clientWithCheckpoints([10_867_539n]) as never);

      await expect(
        isTransactionProcessable(l2ToL1({ blockNumber: undefined, receipt: { blockNumber: 10_867_665n } as never })),
      ).resolves.toBe(false);

      await expect(
        isTransactionProcessable(l2ToL1({ blockNumber: undefined, receipt: { blockNumber: 10_000_000n } as never })),
      ).resolves.toBe(true);
    });
  });

  describe('L1 to L2', () => {
    it('compares against the anchor block the destination chain has reached', async () => {
      vi.mocked(readContract).mockResolvedValue({ anchorBlockNumber: 10_867_539n } as never);
      await expect(isTransactionProcessable(l1ToL2())).resolves.toBe(false);

      vi.mocked(readContract).mockResolvedValue({ anchorBlockNumber: 10_867_665n } as never);
      await expect(isTransactionProcessable(l1ToL2())).resolves.toBe(true);
    });

    it('is null when the anchor read fails', async () => {
      vi.mocked(readContract).mockRejectedValue(new Error('rate limited'));

      await expect(isTransactionProcessable(l1ToL2())).resolves.toBe(null);
    });
  });
});
