import { describe, expect, it } from 'vitest';

import { MANUAL_CLAIM_ROUTE, getManualClaimHref } from './noneOption';

describe('getManualClaimHref', () => {
  it('returns the transactions route when None is selected and the user has enough ETH', () => {
    expect(getManualClaimHref({ selected: true, enoughEth: true })).toBe(MANUAL_CLAIM_ROUTE);
  });

  it('returns null when the user cannot claim manually yet', () => {
    expect(getManualClaimHref({ selected: false, enoughEth: true })).toBeNull();
    expect(getManualClaimHref({ selected: true, enoughEth: false })).toBeNull();
  });
});
