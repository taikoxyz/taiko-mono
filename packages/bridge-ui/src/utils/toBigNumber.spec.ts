import { toBigNumber } from './toBigNumber';

describe('toBigNumber', () => {
  it('should handle different notation for big ints', () => {
    expect(toBigNumber('1000000000000000000000').toString()).toEqual(
      '1000000000000000000000',
    );
    expect(toBigNumber(2e21).toString()).toEqual('2000000000000000000000');
    expect(toBigNumber(3e21).toString()).toEqual('3000000000000000000000');
    expect(toBigNumber(1000).toString()).toEqual('1000');

    // Number.MAX_SAFE_INTEGER = 9007199254740991. Maximum safe integer (2^53 – 1)
    expect(
      toBigNumber(BigInt(Number.MAX_SAFE_INTEGER) * 3n).toString(),
    ).toEqual('27021597764222973');
  });
});
