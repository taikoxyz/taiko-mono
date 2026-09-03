import { MessageStatus } from '$libs/bridge';

import { claimedByRelayer } from './claimedByRelayer';

const OWNER = '0x1111111111111111111111111111111111111111';
const RELAYER = '0x2222222222222222222222222222222222222222';

const args = (overrides = {}) => ({
  claimedBy: RELAYER,
  to: OWNER,
  destOwner: OWNER,
  status: MessageStatus.DONE,
  ...overrides,
});

describe('claimedByRelayer', () => {
  it('recognises a claim by neither the recipient nor the destination owner', () => {
    expect(claimedByRelayer(args())).toBe(true);
  });

  it('does not call an unknown claimer a relayer', () => {
    // A locally recorded transaction carries no claimedBy, and every one of them was
    // being reported as claimed by the relayer
    expect(claimedByRelayer(args({ claimedBy: null }))).toBe(false);
    expect(claimedByRelayer(args({ claimedBy: undefined }))).toBe(false);
  });

  it('does not attribute a self-claim to a relayer', () => {
    expect(claimedByRelayer(args({ claimedBy: OWNER }))).toBe(false);
  });

  it('compares addresses without regard to casing', () => {
    expect(claimedByRelayer(args({ claimedBy: OWNER.toUpperCase().replace('0X', '0x') }))).toBe(false);
  });

  it('attributes nothing before the message is claimed', () => {
    expect(claimedByRelayer(args({ status: MessageStatus.NEW }))).toBe(false);
    expect(claimedByRelayer(args({ status: undefined }))).toBe(false);
  });

  it('recognises a relayer claim when only the destination owner differs from the recipient', () => {
    expect(claimedByRelayer(args({ destOwner: RELAYER }))).toBe(false);
  });
});
