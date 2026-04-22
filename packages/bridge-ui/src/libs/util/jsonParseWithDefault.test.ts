import { jsonParseWithDefault } from './jsonParseWithDefault';

describe('jsonToArray', () => {
  it('should return default value when input is null or empty string', () => {
    expect(jsonParseWithDefault(null, [])).toEqual([]);
    expect(jsonParseWithDefault('', 5)).toEqual(5);
  });

  it('should return default value when input is not a valid JSON', () => {
    expect(jsonParseWithDefault(undefined, true)).toEqual(true);
    expect(jsonParseWithDefault('not a valid JSON', '')).toEqual('');
  });

  it('should return parsed JSON when input is a valid JSON', () => {
    const strJson = '{"person": "Fran", "age": "Unknown"}';
    expect(jsonParseWithDefault(strJson, null)).toEqual(JSON.parse(strJson));
  });
});
