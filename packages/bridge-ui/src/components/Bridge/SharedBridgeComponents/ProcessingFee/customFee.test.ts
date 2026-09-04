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

  it('treats a lone decimal point as incomplete rather than as a zero fee', () => {
    // viem parses '.' as 0, so the old behaviour dropped the fee to zero the moment the
    // user typed a decimal point. Incomplete input must leave the previous fee alone.
    expect(parseCustomFeeInput('.')).toBeNull();
  });

  it('returns null for invalid or negative input', () => {
    expect(parseCustomFeeInput('abc')).toBeNull();
    expect(parseCustomFeeInput('1e18')).toBeNull();
    expect(parseCustomFeeInput('-1')).toBeNull();
  });

  describe('inputs that would be silently reinterpreted', () => {
    it('refuses hex, which parseUnits reads as decimal digits', () => {
      // '0x10' reached parseUnits as decimal digits: roughly 75,557 ETH as a fee
      expect(parseCustomFeeInput('0x10')).toBeNull();
    });

    it('refuses negative fees', () => {
      expect(parseCustomFeeInput('-1')).toBeNull();
    });

    it('refuses exponent notation a number input can emit', () => {
      expect(parseCustomFeeInput('1e5')).toBeNull();
    });

    it('refuses more precision than wei can carry', () => {
      expect(parseCustomFeeInput('0.' + '0'.repeat(18) + '1')).toBeNull();
    });

    it('still accepts an ordinary fee', () => {
      expect(parseCustomFeeInput('0.001')).toBe(BigInt('1000000000000000'));
    });
  });
});
