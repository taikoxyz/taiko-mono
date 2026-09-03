import { parseDecimalAmount } from '$libs/util/parseDecimalAmount';

/** ETH is always 18 decimals */
const ETH_DECIMALS = 18;

/**
 * @dev Parses the custom-fee text input. Returns null while the text is not a complete,
 *      valid, non-negative ETH amount, so callers can leave prior state untouched while
 *      the user is still typing.
 *
 *      Delegates to parseDecimalAmount so the fee box refuses the same inputs every other
 *      amount box refuses. It previously guarded negatives but not hex, and `0x10` reached
 *      parseUnits as decimal digits - roughly 75,557 ETH offered as a processing fee.
 *
 * @param value The raw input value
 * @return The fee in wei, or null when the input cannot be used
 */
export function parseCustomFeeInput(value: string): bigint | null {
  const result = parseDecimalAmount(value, ETH_DECIMALS);
  return result.ok ? result.value : null;
}

/**
 * @dev Whether the box holds nothing to judge yet.
 *
 *      Blank, whitespace, or a bare decimal point - `.` is what a user typing `.5` passes
 *      through. All of them are a box mid-typing rather than a mistake to report, and the
 *      component cannot tell them apart from a null parse plus a non-empty string, because
 *      `.` is exactly that. parseDecimalAmount already draws the line; this exposes it.
 *
 * @param value The raw input value
 * @return blank_ Whether there is nothing yet to accept or refuse
 */
export function isCustomFeeInputBlank(value: string): boolean {
  const result = parseDecimalAmount(value, ETH_DECIMALS);
  return !result.ok && result.reason === 'EMPTY';
}
