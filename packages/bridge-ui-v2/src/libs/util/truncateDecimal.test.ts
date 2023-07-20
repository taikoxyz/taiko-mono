import { truncateDecimal } from './truncateDecimal';

describe('truncateDecimal', () => {
  it('should truncate decimals', () => {
    expect(truncateDecimal(1.23456789, 2)).toEqual(1.23);
    expect(truncateDecimal(12.3456789, 3)).toEqual(12.345);
    expect(truncateDecimal(123.456789, 4)).toEqual(123.4567);
  });
});
