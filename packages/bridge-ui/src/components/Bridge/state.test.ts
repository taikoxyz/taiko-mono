/**
 * The ERC20 send plan is read for one token and does not outlive the selection. It is cleared
 * the moment the selection moves - synchronously, so nothing can act on a plan for a token
 * that is no longer selected - and kept across a refresh that rebuilds the same token.
 */
import { get } from 'svelte/store';
import { vi } from 'vitest';

vi.mock('$bridgeConfig');
vi.mock('@wagmi/core');

import { type Token, TokenType } from '$libs/token';

import { erc20SendPlan, selectedToken } from './state';

const usdc = {
  type: TokenType.ERC20,
  symbol: 'USDC',
  name: 'USD Coin',
  decimals: 6,
  addresses: { 1: '0x0000000000000000000000000000000000000aaa' },
} as Token;
const usdt = {
  ...usdc,
  symbol: 'USDT',
  name: 'Tether',
  addresses: { 1: '0x0000000000000000000000000000000000000bbb' },
} as Token;
const plan = { method: 'sendToken' } as const;

beforeEach(() => {
  selectedToken.set(null);
  erc20SendPlan.set(null);
});

describe('erc20SendPlan', () => {
  it('is cleared the moment the selection moves to another token', () => {
    selectedToken.set(usdc);
    erc20SendPlan.set(plan);

    selectedToken.set(usdt);

    expect(get(erc20SendPlan)).toBeNull();
  });

  it('survives a refresh that rebuilds the same token', () => {
    selectedToken.set(usdc);
    erc20SendPlan.set(plan);

    selectedToken.set({ ...usdc });

    expect(get(erc20SendPlan)).toEqual(plan);
  });

  it('is cleared when the selection is dropped', () => {
    selectedToken.set(usdc);
    erc20SendPlan.set(plan);

    selectedToken.set(null);

    expect(get(erc20SendPlan)).toBeNull();
  });
});
