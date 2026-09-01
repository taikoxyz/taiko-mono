import { parseUnits } from 'viem';

/** The largest value a uint256 can hold; anything above it cannot be encoded */
export const UINT256_MAX = BigInt(2) ** BigInt(256) - BigInt(1);

export type AmountParseFailure =
  /** Nothing to parse yet - the box is empty or holds only a decimal point */
  | 'EMPTY'
  /** Hex, exponent form, separators, whitespace or anything else that is not plain decimal */
  | 'NOT_DECIMAL'
  /** A leading minus sign */
  | 'NEGATIVE'
  /** More fractional digits than the token can represent */
  | 'TOO_MANY_DECIMALS'
  /** Larger than a uint256 can carry */
  | 'EXCEEDS_UINT256';

export type AmountParseResult = { ok: true; value: bigint } | { ok: false; reason: AmountParseFailure };

/** Digits, optionally one decimal point, digits. Nothing else at all. */
const PLAIN_DECIMAL = /^(?:\d+(?:\.\d*)?|\.\d+)$/;

/**
 * @dev Parses a user-typed token amount into base units, refusing everything that is not a
 *      plain decimal number.
 *
 *      viem's `parseUnits` is deliberately permissive and silently accepts several forms
 *      that mean something entirely different from what was typed:
 *        parseUnits('0x10', 6)  -> 268435456      hex read as decimal digits
 *        parseUnits('-5', 6)    -> -5000000       a negative amount
 *        parseUnits('+5', 6)    -> 5000000
 *        parseUnits('1.2345678', 6) -> 1234568    excess precision rounded up
 *      The first of those is the same failure as `Number('0x10') === 16`, but in a field
 *      that moves money. Precision is refused rather than rounded, because rounding
 *      changes the amount without telling the person who typed it.
 *
 * @param raw The raw input text
 * @param decimals The token's decimals
 * @return result_ The parsed base-unit amount, or the reason it was refused
 */
export function parseDecimalAmount(raw: string, decimals: number): AmountParseResult {
  if (raw !== raw.trim()) return { ok: false, reason: 'NOT_DECIMAL' };
  if (raw === '' || raw === '.') return { ok: false, reason: 'EMPTY' };
  if (raw.startsWith('-')) return { ok: false, reason: 'NEGATIVE' };
  if (!PLAIN_DECIMAL.test(raw)) return { ok: false, reason: 'NOT_DECIMAL' };

  const [, fraction = ''] = raw.split('.');
  if (fraction.length > decimals) return { ok: false, reason: 'TOO_MANY_DECIMALS' };

  let value: bigint;
  try {
    value = parseUnits(raw, decimals);
  } catch {
    return { ok: false, reason: 'NOT_DECIMAL' };
  }

  if (value > UINT256_MAX) return { ok: false, reason: 'EXCEEDS_UINT256' };
  return { ok: true, value };
}
