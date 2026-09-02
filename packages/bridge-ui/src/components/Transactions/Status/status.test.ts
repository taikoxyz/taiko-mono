import { describe, expect, it } from 'vitest';

import { MessageStatus } from '$libs/bridge/types';
import { BridgePausedError } from '$libs/error';

import { assertBridgeNotPaused, shouldShowManualClaimEntry } from './status';

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

describe('assertBridgeNotPaused', () => {
  it('throws a BridgePausedError when the bridge is paused', () => {
    expect(() => assertBridgeNotPaused(true)).toThrow(BridgePausedError);
  });

  it('does nothing when the bridge is not paused', () => {
    expect(() => assertBridgeNotPaused(false)).not.toThrow();
  });
});
