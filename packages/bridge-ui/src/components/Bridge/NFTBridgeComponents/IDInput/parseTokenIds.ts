/** How a list of typed token ids came out */
export type TokenIdParseResult = {
  /** The ids to show back in the field, capped at the limit */
  ids: number[];
  /** The ids the import may act on: empty unless every entry was well formed */
  validIds: number[];
  /** True when nothing has been entered yet, which is neither valid nor an error */
  empty: boolean;
};

/**
 * @dev Parses a comma-separated list of token ids.
 *
 *      Every entry has to be strictly decimal and inside the safe-integer range. Both
 *      guards exist because the alternative is acting on a different token than the one
 *      on screen: `Number('0x10')` is 16, `Number('1e5')` is 100000, and an id above
 *      `Number.MAX_SAFE_INTEGER` loses its low digits the moment it becomes a JS number.
 *      A `type="number"` field accepts `1e5` and long digit strings natively, so neither
 *      is hypothetical.
 *
 *      A malformed entry makes the whole list invalid rather than dropping just that
 *      entry. Dropping it left the field non-empty while `validIds` was empty, and the
 *      import then ran an ownership check over an empty id list - which every() answers
 *      `true` for.
 *
 * @param raw The raw input text
 * @param limit The most ids the flow can carry
 * @return result_ The ids to display, the ids that may be used, and whether the field is empty
 */
export function parseTokenIds(raw: string, limit: number): TokenIdParseResult {
  const entries = raw
    .split(',')
    .map((item) => item.trim())
    .filter((item) => item !== '');

  if (entries.length === 0) return { ids: [], validIds: [], empty: true };

  const wellFormed = entries.filter((item) => /^\d+$/.test(item)).map(Number);
  const ids = wellFormed.slice(0, limit);

  const allEntriesWellFormed = wellFormed.length === entries.length;
  const allInSafeRange = wellFormed.every((num) => Number.isSafeInteger(num) && num >= 0);
  const valid = allEntriesWellFormed && ids.length > 0 && allInSafeRange;

  return { ids, validIds: valid ? ids : [], empty: false };
}
