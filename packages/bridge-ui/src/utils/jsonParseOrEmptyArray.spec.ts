import { jsonParseOrEmptyArray } from './jsonParseOrEmptyArray';

describe('jsonParseOrEmptyArray', () => {
  it('should return empty array when input is null or empty string', () => {
    expect(jsonParseOrEmptyArray(null)).toEqual([]);
    expect(jsonParseOrEmptyArray('')).toEqual([]);
  });

  it('should return empty array when input is not a valid JSON', () => {
    expect(jsonParseOrEmptyArray(undefined)).toEqual([]);
    expect(jsonParseOrEmptyArray('not a valid JSON')).toEqual([]);
  });

  it('should return parsed JSON when input is a valid JSON', () => {
    const strJson = '{"person": "Fran", "age": "Unknown"}';
    expect(jsonParseOrEmptyArray(strJson)).toEqual(JSON.parse(strJson));
  });
});
