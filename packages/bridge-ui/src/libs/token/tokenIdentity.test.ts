import type { Address } from 'viem';

import { tokenIdentityKey, tokensAreSame } from './tokenIdentity';
import { type Token, TokenType } from './types';

const token = (overrides: Partial<Token>): Token =>
  ({
    name: 'Token',
    symbol: 'TKN',
    decimals: 18,
    type: TokenType.ERC20,
    addresses: {},
    ...overrides,
  }) as Token;

describe('tokensAreSame', () => {
  it('matches tokens sharing a deployment on the same chain, case-insensitively', () => {
    const a = token({ addresses: { 1: '0xAbC0000000000000000000000000000000000001' as Address } });
    const b = token({ symbol: 'OTHER', addresses: { 1: '0xabc0000000000000000000000000000000000001' as Address } });
    expect(tokensAreSame(a, b)).toBe(true);
  });

  it('does not match unrelated tokens at the same address on different chains', () => {
    const a = token({ addresses: { 1: '0xabc0000000000000000000000000000000000001' as Address } });
    const b = token({ addresses: { 167000: '0xabc0000000000000000000000000000000000001' as Address } });
    expect(tokensAreSame(a, b)).toBe(false);
  });

  it('falls back to the symbol only when no addresses are known', () => {
    expect(tokensAreSame(token({}), token({}))).toBe(true);
    expect(tokensAreSame(token({}), token({ symbol: 'OTHER' }))).toBe(false);
  });
});

describe('tokenIdentityKey', () => {
  it('produces distinct keys for same-symbol tokens at different deployments', () => {
    const a = token({ addresses: { 1: '0xabc0000000000000000000000000000000000001' as Address } });
    const b = token({ addresses: { 1: '0xdef0000000000000000000000000000000000002' as Address } });
    expect(tokenIdentityKey(a)).not.toEqual(tokenIdentityKey(b));
  });

  it('falls back to the symbol for address-less tokens', () => {
    expect(tokenIdentityKey(token({}))).toBe('TKN');
  });
});
