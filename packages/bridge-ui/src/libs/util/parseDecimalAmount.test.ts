import { parseDecimalAmount, UINT256_MAX } from './parseDecimalAmount';

const ok = (raw: string, decimals: number) => {
  const result = parseDecimalAmount(raw, decimals);
  if (!result.ok) throw new Error(`expected ${raw} to parse, got ${result.reason}`);
  return result.value;
};
const reason = (raw: string, decimals: number) => {
  const result = parseDecimalAmount(raw, decimals);
  return result.ok ? 'PARSED' : result.reason;
};

describe('parseDecimalAmount', () => {
  it('parses plain decimals at the token precision', () => {
    expect(ok('1', 18)).toBe(BigInt('1000000000000000000'));
    expect(ok('0.5', 6)).toBe(BigInt(500000));
    expect(ok('100', 6)).toBe(BigInt(100000000));
    expect(ok('.5', 6)).toBe(BigInt(500000));
    expect(ok('1.', 6)).toBe(BigInt(1000000));
    expect(ok('0', 6)).toBe(BigInt(0));
  });

  describe('refuses what viem would silently reinterpret', () => {
    it('refuses hex, which parseUnits reads as decimal digits', () => {
      // parseUnits('0x10', 6) is 268435456 - the same failure as Number('0x10') === 16,
      // but in a field that moves money
      expect(reason('0x10', 6)).toBe('NOT_DECIMAL');
      expect(reason('0xdeadbeef', 18)).toBe('NOT_DECIMAL');
    });

    it('refuses negative amounts', () => {
      expect(reason('-5', 6)).toBe('NEGATIVE');
      expect(reason('-0.1', 18)).toBe('NEGATIVE');
    });

    it('refuses a leading plus', () => {
      expect(reason('+5', 6)).toBe('NOT_DECIMAL');
    });

    it('refuses exponent notation', () => {
      // Number inputs emit this natively
      expect(reason('1e5', 18)).toBe('NOT_DECIMAL');
      expect(reason('1E5', 18)).toBe('NOT_DECIMAL');
    });

    it('refuses padding and separators', () => {
      expect(reason('  7  ', 6)).toBe('NOT_DECIMAL');
      expect(reason('1_000', 6)).toBe('NOT_DECIMAL');
      expect(reason('1,000', 6)).toBe('NOT_DECIMAL');
    });

    it('refuses non-numeric text', () => {
      expect(reason('abc', 6)).toBe('NOT_DECIMAL');
      expect(reason('Infinity', 18)).toBe('NOT_DECIMAL');
      expect(reason('NaN', 18)).toBe('NOT_DECIMAL');
      expect(reason('1.2.3', 18)).toBe('NOT_DECIMAL');
    });
  });

  describe('precision', () => {
    it('refuses more decimals than the token has, rather than rounding', () => {
      // parseUnits('1.2345678', 6) rounds to 1234568 - a different amount than was typed
      expect(reason('1.2345678', 6)).toBe('TOO_MANY_DECIMALS');
      expect(reason('0.0000001', 6)).toBe('TOO_MANY_DECIMALS');
    });

    it('accepts exactly the supported precision', () => {
      expect(ok('1.234567', 6)).toBe(BigInt(1234567));
      expect(ok('0.000001', 6)).toBe(BigInt(1));
    });

    it('treats a zero-decimal token as integer-only', () => {
      expect(ok('5', 0)).toBe(BigInt(5));
      expect(reason('1.5', 0)).toBe('TOO_MANY_DECIMALS');
    });
  });

  describe('bounds', () => {
    it('refuses a value larger than a uint256', () => {
      expect(reason('1'.repeat(80), 18)).toBe('EXCEEDS_UINT256');
    });

    it('accepts the largest representable value', () => {
      expect(ok(UINT256_MAX.toString(), 0)).toBe(UINT256_MAX);
    });

    it('refuses one above the largest representable value', () => {
      expect(reason((UINT256_MAX + BigInt(1)).toString(), 0)).toBe('EXCEEDS_UINT256');
    });
  });

  describe('incomplete input', () => {
    it('reports an empty box as empty, not invalid', () => {
      expect(reason('', 18)).toBe('EMPTY');
      expect(reason('.', 18)).toBe('EMPTY');
    });

    it('reports a whitespace-only box as empty too', () => {
      // Consistent with parseTokenIds, and it decides whether the field shows an error:
      // spaces are a box nobody filled in, not a mistake worth reporting
      expect(reason('   ', 18)).toBe('EMPTY');
      expect(reason('\t', 18)).toBe('EMPTY');
    });

    it('still refuses padding around an actual value', () => {
      expect(reason(' 5 ', 6)).toBe('NOT_DECIMAL');
    });
  });
});
