import type { Message } from '$libs/bridge';

import { isClaimFeeContestable } from './isClaimFeeContestable';

const message = (gasLimit: number, fee: bigint) => ({ gasLimit, fee }) as Message;

describe('isClaimFeeContestable', () => {
  it('is contestable when a fee is on offer and anyone may process the message', () => {
    expect(isClaimFeeContestable(message(1_000_000, 100n))).toBe(true);
  });

  it('is not contestable with no fee: winning the race only spends gas on someone else behalf', () => {
    expect(isClaimFeeContestable(message(1_000_000, 0n))).toBe(false);
  });

  it('is not contestable at gasLimit 0: the bridge lets only the destination owner process it', () => {
    expect(isClaimFeeContestable(message(0, 0n))).toBe(false);
    expect(isClaimFeeContestable(message(0, 100n))).toBe(false);
  });
});
