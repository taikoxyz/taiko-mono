import { describe, expect, it } from 'vitest';

import { isMessageNotReceivedError } from './error';

describe('isMessageNotReceivedError', () => {
  it('returns true for legacy and current bridge not received errors', () => {
    expect(isMessageNotReceivedError(new Error('execution reverted: B_NOT_RECEIVED()'))).toBe(true);
    expect(isMessageNotReceivedError(new Error('execution reverted: B_SIGNAL_NOT_RECEIVED()'))).toBe(true);
  });

  it('reads nested cause metadata when viem wraps the revert', () => {
    const wrappedError = {
      message: 'The contract function "processMessage" reverted.',
      cause: {
        shortMessage: 'The contract function reverted.',
        data: {
          errorName: 'B_SIGNAL_NOT_RECEIVED',
        },
      },
    };

    expect(isMessageNotReceivedError(wrappedError)).toBe(true);
  });

  it('returns false for unrelated failures', () => {
    expect(isMessageNotReceivedError(new Error('execution reverted: B_PERMISSION_DENIED()'))).toBe(false);
  });
});
