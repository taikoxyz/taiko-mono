/**
 * The review-step warning and the confirmation-step copy read one expression to decide
 * whether a destination is the slow direction, so those two screens cannot disagree.
 */
const env = vi.hoisted(() => ({ PUBLIC_SLOW_L1_BRIDGING_WARNING: '' }));

vi.mock('$env/static/public', async (importOriginal) => ({
  ...(await importOriginal<typeof import('$env/static/public')>()),
  // A getter, so each test can set the flag without re-importing the module
  get PUBLIC_SLOW_L1_BRIDGING_WARNING() {
    return env.PUBLIC_SLOW_L1_BRIDGING_WARNING;
  },
}));
vi.mock('$chainConfig', () => ({ chainConfig: { 1: { type: 'L1' }, 2: { type: 'L2' } } }));

import { isSlowL1Bridging } from './isSlowL1Bridging';

describe('isSlowL1Bridging', () => {
  it('applies to an L1 destination when the deployment asks for the warning', () => {
    env.PUBLIC_SLOW_L1_BRIDGING_WARNING = 'true';
    expect(isSlowL1Bridging(1)).toBe(true);
  });

  it('does not apply to an L2 destination', () => {
    env.PUBLIC_SLOW_L1_BRIDGING_WARNING = 'true';
    expect(isSlowL1Bridging(2)).toBe(false);
  });

  it('does not apply when the deployment does not ask for it', () => {
    env.PUBLIC_SLOW_L1_BRIDGING_WARNING = '';
    expect(isSlowL1Bridging(1)).toBe(false);
  });

  it('does not apply without a destination, or to one that is not configured', () => {
    env.PUBLIC_SLOW_L1_BRIDGING_WARNING = 'true';
    expect(isSlowL1Bridging(undefined)).toBe(false);
    expect(isSlowL1Bridging(999)).toBe(false);
  });
});
