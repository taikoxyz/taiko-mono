import { parseCustomFeeInput } from './customFee';

describe('parseCustomFeeInput', () => {
  it('parses a valid decimal ETH amount to wei', () => {
    expect(parseCustomFeeInput('0.01')).toBe(10_000_000_000_000_000n);
    expect(parseCustomFeeInput('1')).toBe(1_000_000_000_000_000_000n);
  });

  it('accepts amounts below any recommended fee — a custom fee may undercut it', () => {
    expect(parseCustomFeeInput('0.000000001')).toBe(1_000_000_000n);
    expect(parseCustomFeeInput('0')).toBe(0n);
  });

  it('returns null for empty input so typing is not hijacked', () => {
    expect(parseCustomFeeInput('')).toBeNull();
    expect(parseCustomFeeInput('  ')).toBeNull();
  });

  it('treats a lone decimal point as zero while the user is typing', () => {
    expect(parseCustomFeeInput('.')).toBe(0n);
  });

  it('returns null for invalid or negative input', () => {
    expect(parseCustomFeeInput('abc')).toBeNull();
    expect(parseCustomFeeInput('1e18')).toBeNull();
    expect(parseCustomFeeInput('-1')).toBeNull();
  });
});
