import { parseToWei } from '$libs/util/parseToWei';

/**
 * @dev Parses the custom-fee text input. Returns null while the text is not a complete,
 *      valid, non-negative ETH amount, so callers can leave prior state untouched while
 *      the user is still typing.
 * @param value The raw input value
 * @return The fee in wei, or null when the input cannot be used
 */
export function parseCustomFeeInput(value: string): bigint | null {
  if (value.trim() === '') return null;

  let parsed: bigint;
  try {
    parsed = parseToWei(value);
  } catch {
    return null;
  }

  if (parsed < BigInt(0)) return null;
  return parsed;
}
