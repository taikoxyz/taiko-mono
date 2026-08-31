import { formatTokenAmount } from './formatTokenAmount';

describe('formatTokenAmount', () => {
  it('formats using the token decimals, not 18', () => {
    // 100 USDC (6 decimals)
    expect(formatTokenAmount(100_000_000n, 6)).toBe('100');
    // 1.5 WBTC (8 decimals)
    expect(formatTokenAmount(150_000_000n, 8)).toBe('1.5');
  });

  it('defaults to 18 decimals for ETH-style amounts', () => {
    expect(formatTokenAmount(1_000_000_000_000_000_000n)).toBe('1');
    expect(formatTokenAmount(1_000_000_000_000_000_000n, undefined)).toBe('1');
    expect(formatTokenAmount(1_000_000_000_000_000_000n, null)).toBe('1');
  });

  it('renders 0 for missing amounts', () => {
    expect(formatTokenAmount(undefined, 6)).toBe('0');
    expect(formatTokenAmount(null)).toBe('0');
  });
});
