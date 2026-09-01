import { parseTokenIds } from './parseTokenIds';

describe('parseTokenIds', () => {
  it('accepts a single decimal id', () => {
    expect(parseTokenIds('7', 1)).toEqual({ ids: [7], validIds: [7], empty: false });
  });

  it('accepts id zero', () => {
    expect(parseTokenIds('0', 1)).toEqual({ ids: [0], validIds: [0], empty: false });
  });

  it('reports an empty or whitespace-only field as empty, not invalid', () => {
    expect(parseTokenIds('', 1)).toEqual({ ids: [], validIds: [], empty: true });
    expect(parseTokenIds('   ', 1)).toEqual({ ids: [], validIds: [], empty: true });
    expect(parseTokenIds(' , , ', 1)).toEqual({ ids: [], validIds: [], empty: true });
  });

  describe('refuses values that would target a different token', () => {
    it('refuses hex', () => {
      // Number('0x10') is 16
      expect(parseTokenIds('0x10', 1).validIds).toEqual([]);
      // and reports it as entered-but-invalid, so the field reddens rather than sitting
      // there looking untouched
      expect(parseTokenIds('0x10', 1).empty).toBe(false);
    });

    it('refuses exponent notation, which a number field accepts natively', () => {
      // Number('1e5') is 100000
      expect(parseTokenIds('1e5', 1)).toEqual({ ids: [], validIds: [], empty: false });
    });

    it('refuses negatives and decimals', () => {
      expect(parseTokenIds('-1', 1).validIds).toEqual([]);
      expect(parseTokenIds('1.5', 1).validIds).toEqual([]);
    });

    it('refuses an id above the safe-integer range', () => {
      // Number('9007199254740993') is 9007199254740992 - the id next door
      expect(parseTokenIds('9007199254740993', 1).validIds).toEqual([]);
    });

    it('accepts the largest safe integer', () => {
      expect(parseTokenIds('9007199254740991', 1).validIds).toEqual([9007199254740991]);
    });
  });

  describe('a malformed entry invalidates the whole list', () => {
    it('does not quietly keep the entries it could parse', () => {
      // Keeping just [1] left the field non-empty while the import carried one id the
      // user never singled out
      expect(parseTokenIds('1,abc', 2).validIds).toEqual([]);
    });

    it('does not quietly keep the entries alongside an unsafe id', () => {
      expect(parseTokenIds('1,9007199254740993', 2).validIds).toEqual([]);
    });

    it('never reports non-empty ids with an empty valid list as usable', () => {
      const result = parseTokenIds('1,abc', 1);
      expect(result.empty).toBe(false);
      expect(result.ids.length).toBeGreaterThan(0);
      expect(result.validIds).toEqual([]);
    });
  });

  describe('limit', () => {
    it('refuses a list longer than the limit instead of trimming it', () => {
      // Trimming reported the list as valid while discarding the rest, so pasting two ids
      // into a field that carries one bridged the first without saying so
      expect(parseTokenIds('1,2,3', 2)).toEqual({ ids: [1, 2], validIds: [], empty: false });
      expect(parseTokenIds('1,2', 1).validIds).toEqual([]);
    });

    it('accepts a list exactly at the limit', () => {
      expect(parseTokenIds('1,2', 2).validIds).toEqual([1, 2]);
    });
  });
});
