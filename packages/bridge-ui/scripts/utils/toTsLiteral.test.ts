import { describe, expect, it } from 'vitest';

import { toTsLiteral, tsExpression } from './toTsLiteral';

describe('toTsLiteral', () => {
  it('serializes primitive values', () => {
    expect(toTsLiteral(null)).toBe('null');
    expect(toTsLiteral(undefined)).toBe('undefined');
    expect(toTsLiteral(42n)).toBe('42n');
    expect(toTsLiteral('quoted"value')).toBe('"quoted\\"value"');
    expect(toTsLiteral(true)).toBe('true');
  });

  it('serializes arrays and deeply nested plain objects', () => {
    expect(
      toTsLiteral({
        nested: {
          values: ['a', 1, false, null, undefined, 2n],
        },
      }),
    ).toBe('{"nested": {"values": ["a", 1, false, null, undefined, 2n]}}');
  });

  it('rejects non-finite numbers', () => {
    expect(() => toTsLiteral(Number.NaN)).toThrow(/Cannot serialize non-finite number: NaN/);
    expect(() => toTsLiteral(Number.POSITIVE_INFINITY)).toThrow(/Cannot serialize non-finite number: Infinity/);
    expect(() => toTsLiteral(Number.NEGATIVE_INFINITY)).toThrow(/Cannot serialize non-finite number: -Infinity/);
  });

  it('rejects non-plain objects', () => {
    expect(() => toTsLiteral(new Date('2026-01-01T00:00:00.000Z'))).toThrow(/Cannot serialize non-plain object: Date/);
    expect(() => toTsLiteral(/unsafe/u)).toThrow(/Cannot serialize non-plain object: RegExp/);
  });

  it('allows only simple member expressions as TypeScript expressions', () => {
    expect(toTsLiteral(tsExpression('TokenType.ERC20'))).toBe('TokenType.ERC20');
    expect(toTsLiteral(tsExpression('LayerType.L1'))).toBe('LayerType.L1');
    expect(() => tsExpression('TokenType.ERC20; globalThis.evil()')).toThrow(/Invalid TypeScript expression/);
    expect(() => tsExpression('TokenType["ERC20"]')).toThrow(/Invalid TypeScript expression/);
  });
});
