import { hasEnabledPrivateRpc, rememberEnabledPrivateRpc } from './privateRpcPreference';

describe('privateRpcPreference', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it('does not claim the relay is enabled before the user accepted it', () => {
    expect(hasEnabledPrivateRpc(1)).toBe(false);
  });

  it('remembers the choice per chain', () => {
    rememberEnabledPrivateRpc(1);

    expect(hasEnabledPrivateRpc(1)).toBe(true);
    expect(hasEnabledPrivateRpc(11155111)).toBe(false);
  });
});
