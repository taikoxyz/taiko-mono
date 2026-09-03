/**
 * The claim transaction of a claimed message, asked of every configured relayer in turn. Each
 * relayer files its status rows under the message's sender, so the lookup is made with that
 * address rather than with the account whose history is on screen.
 */
const relayers = vi.hoisted(() => [{ getClaimTxHash: vi.fn() }, { getClaimTxHash: vi.fn() }]);
vi.mock('./initRelayers', () => ({ relayerApiServices: relayers }));

import { findClaimTxHash } from './findClaimTxHash';

const SENDER = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';
const MSG_HASH = `0x${'ab'.repeat(32)}` as const;
const CLAIM_TX = `0x${'cd'.repeat(32)}` as const;

beforeEach(() => {
  relayers[0].getClaimTxHash.mockReset();
  relayers[1].getClaimTxHash.mockReset();
});

describe('findClaimTxHash', () => {
  it('takes the first answer and asks no further', async () => {
    relayers[0].getClaimTxHash.mockResolvedValue(CLAIM_TX);

    expect(await findClaimTxHash(SENDER, MSG_HASH)).toBe(CLAIM_TX);
    expect(relayers[0].getClaimTxHash).toHaveBeenCalledWith(SENDER, MSG_HASH);
    expect(relayers[1].getClaimTxHash).not.toHaveBeenCalled();
  });

  it('moves on from a relayer that has no answer, and from one that fails', async () => {
    relayers[0].getClaimTxHash.mockRejectedValue(new Error('relayer down'));
    relayers[1].getClaimTxHash.mockResolvedValue(CLAIM_TX);
    expect(await findClaimTxHash(SENDER, MSG_HASH)).toBe(CLAIM_TX);

    relayers[0].getClaimTxHash.mockResolvedValue(undefined);
    expect(await findClaimTxHash(SENDER, MSG_HASH)).toBe(CLAIM_TX);
  });

  it('answers nothing when no relayer knows the claim', async () => {
    relayers[0].getClaimTxHash.mockResolvedValue(undefined);
    relayers[1].getClaimTxHash.mockRejectedValue(new Error('relayer down'));

    expect(await findClaimTxHash(SENDER, MSG_HASH)).toBeUndefined();
  });
});
