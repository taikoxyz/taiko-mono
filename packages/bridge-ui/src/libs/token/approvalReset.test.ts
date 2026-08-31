import type { Address } from 'viem';

import { tokenNeedsAllowanceReset } from './approvalReset';
import { type Token, TokenType } from './types';

const USDT_MAINNET = '0xdAC17F958D2ee523a2206206994597C13D831ec7' as Address;

const token = (overrides: Partial<Token>): Token =>
  ({
    name: 'Token',
    symbol: 'TKN',
    decimals: 6,
    type: TokenType.ERC20,
    addresses: {},
    ...overrides,
  }) as Token;

describe('tokenNeedsAllowanceReset', () => {
  it('detects mainnet USDT by its address on the connected chain', () => {
    const usdt = token({ symbol: 'USDT', addresses: { 1: USDT_MAINNET } });
    expect(tokenNeedsAllowanceReset(usdt, 1)).toBe(true);
  });

  it('matches the USDT address case-insensitively', () => {
    const usdt = token({ symbol: 'USDT', addresses: { 1: USDT_MAINNET.toLowerCase() as Address } });
    expect(tokenNeedsAllowanceReset(usdt, 1)).toBe(true);
  });

  it('detects the tUSDT test token by symbol regardless of address', () => {
    const tUsdt = token({ symbol: 'tUSDT', addresses: { 167001: '0x1234' as Address } });
    expect(tokenNeedsAllowanceReset(tUsdt, 167001)).toBe(true);
  });

  it('returns false for regular tokens', () => {
    const dai = token({ symbol: 'DAI', addresses: { 1: '0x6B175474E89094C44Da98b954EedeAC495271d0F' as Address } });
    expect(tokenNeedsAllowanceReset(dai, 1)).toBe(false);
  });

  it('does not flag a token that only holds the USDT address on a different chain', () => {
    const bridged = token({ symbol: 'USDT', addresses: { 1: USDT_MAINNET, 167001: '0x9999' as Address } });
    expect(tokenNeedsAllowanceReset(bridged, 167001)).toBe(false);
  });

  it('handles missing token or chain gracefully', () => {
    expect(tokenNeedsAllowanceReset(null, 1)).toBe(false);
    expect(tokenNeedsAllowanceReset(token({ symbol: 'USDT' }), undefined)).toBe(false);
  });
});
