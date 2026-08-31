import { truncateDecimal, truncateDecimalString } from './truncateDecimal';

describe('truncateDecimal', () => {
  it('should truncate decimals', () => {
    expect(truncateDecimal(1.23456789, 2)).toEqual(1.23);
    expect(truncateDecimal(12.3456789, 3)).toEqual(12.345);
    expect(truncateDecimal(123.456789, 4)).toEqual(123.4567);
  });
});

describe('truncateDecimalString', () => {
  it('truncates the decimal part of a string', () => {
    expect(truncateDecimalString('1.23456789', 2)).toEqual('1.23');
    expect(truncateDecimalString('123.456789', 4)).toEqual('123.4567');
  });

  it('keeps tiny values out of scientific notation', () => {
    expect(truncateDecimalString('0.0000001', 12)).toEqual('0.0000001');
    expect(truncateDecimalString('0.000000123456789012345678', 12)).toEqual('0.000000123456');
  });

  it('drops trailing zeros and empty decimal parts', () => {
    expect(truncateDecimalString('1.5000', 12)).toEqual('1.5');
    expect(truncateDecimalString('2.000', 12)).toEqual('2');
    expect(truncateDecimalString('42', 12)).toEqual('42');
  });
});
