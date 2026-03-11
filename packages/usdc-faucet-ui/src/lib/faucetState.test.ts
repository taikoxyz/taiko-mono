import { describe, expect, it } from 'vitest';

import { deriveFaucetViewState } from '$lib/faucetState';

const baseInput = {
  claimAmountLabel: '25 USDC',
  cooldownUntilMs: null,
  isClaiming: false,
  isConfigured: true,
  isConnected: true,
  isCorrectChain: true,
  isRefreshing: false,
  lastClaimHash: null,
  nowMs: 1_000,
} as const;

describe('deriveFaucetViewState', () => {
  it('asks the user to connect when no wallet is connected', () => {
    const state = deriveFaucetViewState({
      ...baseInput,
      isConnected: false,
    });

    expect(state.primaryAction).toBe('connect');
    expect(state.primaryDisabled).toBe(false);
    expect(state.primaryLabel).toBe('Connect wallet');
  });

  it('gates claims behind the Ethereum Hoodi network', () => {
    const state = deriveFaucetViewState({
      ...baseInput,
      isCorrectChain: false,
    });

    expect(state.primaryAction).toBe('switch');
    expect(state.primaryLabel).toBe('Switch to Ethereum Hoodi');
    expect(state.detail).toContain('only works on Ethereum Hoodi');
  });

  it('disables claiming while the cooldown is active', () => {
    const state = deriveFaucetViewState({
      ...baseInput,
      cooldownUntilMs: 70_000,
    });

    expect(state.cooldownActive).toBe(true);
    expect(state.primaryDisabled).toBe(true);
    expect(state.primaryLabel).toContain('Available in');
    expect(state.showBridgeCta).toBe(false);
  });

  it('shows the bridge CTA after a successful claim', () => {
    const state = deriveFaucetViewState({
      ...baseInput,
      cooldownUntilMs: 70_000,
      lastClaimHash: '0xabc',
    });

    expect(state.cooldownActive).toBe(true);
    expect(state.showBridgeCta).toBe(true);
  });

  it('enables the claim button when the wallet is ready', () => {
    const state = deriveFaucetViewState(baseInput);

    expect(state.primaryAction).toBe('claim');
    expect(state.primaryDisabled).toBe(false);
    expect(state.primaryLabel).toBe('Claim 25 USDC');
  });
});
