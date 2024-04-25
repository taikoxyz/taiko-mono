import { truncateString } from './truncateString';

describe('truncateString', () => {
  it('should truncate strings', () => {
    expect(truncateString('123456789', 3)).toEqual('123…');
    expect(truncateString('123456789', 5)).toEqual('12345…');
    expect(truncateString('123456789', 6, '...')).toEqual('123456...');
  });
});
