import { describe, expect, it } from 'vitest';

import { MessageStatus } from '$libs/bridge/types';

import { shouldShowManualClaimEntry } from './status';

describe('shouldShowManualClaimEntry', () => {
  it('returns true when a none-fee transaction is still processing but can be manually claimed', () => {
    expect(
      shouldShowManualClaimEntry({
        bridgeTxStatus: MessageStatus.NEW,
        isProcessable: false,
        processingFee: 0n,
      }),
    ).toBe(true);
  });

  it('returns false when a relayer fee exists or the transaction is already processable', () => {
    expect(
      shouldShowManualClaimEntry({
        bridgeTxStatus: MessageStatus.NEW,
        isProcessable: false,
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
});
