import { describe, expect, it } from 'vitest';

import { shouldSkipMessageStatusCheck } from './mode';

describe('shouldSkipMessageStatusCheck', () => {
  it('skips the message status check for try claim', () => {
    expect(shouldSkipMessageStatusCheck('try_claim')).toBe(true);
  });

  it('keeps the message status check for the regular claim flow', () => {
    expect(shouldSkipMessageStatusCheck('claim')).toBe(false);
  });
});
