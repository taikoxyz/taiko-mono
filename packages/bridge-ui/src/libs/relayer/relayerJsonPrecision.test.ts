import { preserveMessageIntegerPrecision } from './RelayerAPIService';

/**
 * The relayer response is rewritten before JSON.parse so that integers beyond 2^53 keep
 * their digits. The rewrite must never produce invalid JSON: `amount` and `fee` are not
 * guaranteed to be whole numbers, and quoting only the leading digits of `1.5` yields
 * `"1".5`, which takes the entire transaction list down.
 *
 * The fields come off Go floats, so the rewrite has to read exponent form as well as plain
 * digits: the values large enough to need it are exactly the ones Go prints as `1.85e19`.
 */
const roundTrip = (raw: string) => JSON.parse(preserveMessageIntegerPrecision(raw));

describe('preserveMessageIntegerPrecision', () => {
  it('keeps digits that a JSON number would lose', () => {
    const big = '123456789012345678901234567890';
    expect(roundTrip(`{"Fee":${big}}`).Fee).toBe(big);
    expect(roundTrip(`{"amount":${big}}`).amount).toBe(big);
    expect(roundTrip(`{"fee":${big}}`).fee).toBe(big);
  });

  it('covers every message integer field', () => {
    const raw = '{"Fee":1,"Value":2,"Id":3,"SrcChainId":4,"DestChainId":5}';
    expect(roundTrip(raw)).toEqual({ Fee: '1', Value: '2', Id: '3', SrcChainId: '4', DestChainId: '5' });
  });

  it('leaves a decimal amount as valid JSON', () => {
    expect(() => roundTrip('{"amount":1.5}')).not.toThrow();
    expect(roundTrip('{"amount":1.5}').amount).toBe(1.5);
  });

  it('keeps an exponent-formed integer as digits', () => {
    expect(() => roundTrip('{"amount":1e5}')).not.toThrow();
    expect(roundTrip('{"amount":1e5}').amount).toBe('100000');
  });

  it('keeps the digits of an exponent-formed value past 2^53', () => {
    // 18.5 ETH. Go prints this float as `1.85e19`, which the earlier rewrite left as a JSON
    // number: `parseApiBigInt` then rejected it as unsafe, `_transformTransaction` threw, and
    // the transaction was dropped from the user's list on every refresh
    expect(roundTrip('{"Value":1.85e19}').Value).toBe('18500000000000000000');
  });

  it('keeps an exponent-formed integer that carries a fraction', () => {
    expect(roundTrip('{"Value":1.5e1}').Value).toBe('15');
  });

  it('leaves an exponent-formed fraction as valid JSON', () => {
    expect(roundTrip('{"amount":1.55e1}').amount).toBe(15.5);
    expect(roundTrip('{"amount":5e-2}').amount).toBe(0.05);
  });

  it('leaves a magnitude no bridge value has alone', () => {
    // Nothing is allocated for an absurd exponent; the token stays a number and fails the
    // caller's own check instead
    expect(roundTrip('{"Value":1e1000}').Value).toBe(Infinity);
  });

  it('leaves a decimal fee as valid JSON', () => {
    expect(() => roundTrip('{"fee":0.5}')).not.toThrow();
    expect(roundTrip('{"fee":0.5}').fee).toBe(0.5);
  });

  it('does not corrupt a realistic row mixing whole and fractional values', () => {
    const raw = '{"items":[{"amount":500000000000000,"fee":1.25,"message":{"Fee":130220640000000,"Id":7}}]}';
    const parsed = roundTrip(raw);
    expect(parsed.items[0].amount).toBe('500000000000000');
    expect(parsed.items[0].fee).toBe(1.25);
    expect(parsed.items[0].message.Fee).toBe('130220640000000');
  });

  it('leaves values that are already strings alone', () => {
    expect(roundTrip('{"amount":"500"}').amount).toBe('500');
  });

  it('does not rewrite a field name that appears inside a string value', () => {
    // JSON escapes a quote inside a string, so the closing quote the pattern needs after
    // the field name is never there - a match cannot start inside string content
    const raw = `{"note":${JSON.stringify('the "amount":5 was rejected')},"amount":500000000000000}`;
    const parsed = roundTrip(raw);

    expect(parsed.note).toBe('the "amount":5 was rejected');
    expect(parsed.amount).toBe('500000000000000');
  });

  it('does not rewrite a field name written with unicode escapes in a string value', () => {
    const raw = String.raw`{"note":"\u0022fee\u0022:7","fee":130220640000000}`;
    const parsed = roundTrip(raw);

    expect(parsed.note).toBe('"fee":7');
    expect(parsed.fee).toBe('130220640000000');
  });
});
