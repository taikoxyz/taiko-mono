import { describe, expect, it } from 'vitest';

import type { BridgeTransaction } from '$libs/bridge/types';
import { MessageStatus } from '$libs/bridge/types';
import { BridgePausedError } from '$libs/error';

import {
  assertBridgeNotPaused,
  isEligibleForStorageRemoval,
  shouldShowManualClaimEntry,
  STALE_LOCAL_TX_MAX_AGE_MS,
} from './status';

describe('shouldShowManualClaimEntry', () => {
  it('returns true for a zero-fee transaction whose processability could not be determined', () => {
    expect(
      shouldShowManualClaimEntry({
        bridgeTxStatus: MessageStatus.NEW,
        isProcessable: null,
        processingFee: 0n,
      }),
    ).toBe(true);
  });

  it('returns false while the destination chain is known not to have synced the message yet', () => {
    // `false` is a settled answer: the claim this entry would start is one BridgeProver rejects
    // with BlockNotSyncedError, and the next checkpoint resolves it without the user doing anything
    expect(
      shouldShowManualClaimEntry({
        bridgeTxStatus: MessageStatus.NEW,
        isProcessable: false,
        processingFee: 0n,
      }),
    ).toBe(false);
  });

  it('returns false when a relayer fee exists or the transaction is already processable', () => {
    expect(
      shouldShowManualClaimEntry({
        bridgeTxStatus: MessageStatus.NEW,
        isProcessable: null,
        processingFee: 1n,
      }),
    ).toBe(false);

    expect(
      shouldShowManualClaimEntry({
        bridgeTxStatus: MessageStatus.NEW,
        isProcessable: true,
        processingFee: 0n,
      }),
    ).toBe(false);
  });

  it('returns false for non-new or missing statuses even when the processing fee is zero', () => {
    expect(
      shouldShowManualClaimEntry({
        bridgeTxStatus: MessageStatus.DONE,
        isProcessable: null,
        processingFee: 0n,
      }),
    ).toBe(false);

    expect(
      shouldShowManualClaimEntry({
        bridgeTxStatus: MessageStatus.RETRIABLE,
        isProcessable: null,
        processingFee: 0n,
      }),
    ).toBe(false);

    expect(
      shouldShowManualClaimEntry({
        bridgeTxStatus: null,
        isProcessable: null,
        processingFee: 0n,
      }),
    ).toBe(false);

    expect(
      shouldShowManualClaimEntry({
        bridgeTxStatus: undefined,
        isProcessable: null,
        processingFee: 0n,
      }),
    ).toBe(false);
  });
});

describe('isEligibleForStorageRemoval', () => {
  const NOW = 1_700_000_000_000;

  const tx = (overrides: Partial<BridgeTransaction>) => ({ srcTxHash: '0xabc', ...overrides }) as BridgeTransaction;

  it('keeps a fresh transaction that has no msgHash yet (transient enhancement failure)', () => {
    expect(isEligibleForStorageRemoval(tx({ timestamp: NOW - 60_000 }), NOW)).toBe(false);
  });

  it('keeps a transaction that has a msgHash, however old it is', () => {
    expect(
      isEligibleForStorageRemoval(tx({ msgHash: '0x123', timestamp: NOW - 10 * STALE_LOCAL_TX_MAX_AGE_MS }), NOW),
    ).toBe(false);
  });

  it('keeps a transaction without a timestamp, since its age is unknown', () => {
    expect(isEligibleForStorageRemoval(tx({}), NOW)).toBe(false);
  });

  it('removes a transaction that still has no msgHash after the stale age threshold', () => {
    expect(isEligibleForStorageRemoval(tx({ timestamp: NOW - STALE_LOCAL_TX_MAX_AGE_MS - 1 }), NOW)).toBe(true);
  });
});

describe('assertBridgeNotPaused', () => {
  it('throws a BridgePausedError when the bridge is paused', () => {
    expect(() => assertBridgeNotPaused(true)).toThrow(BridgePausedError);
  });

  it('does nothing when the bridge is not paused', () => {
    expect(() => assertBridgeNotPaused(false)).not.toThrow();
  });
});
