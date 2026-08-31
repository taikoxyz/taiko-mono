export function truncateDecimal(num: number, decimalPlaces: number) {
  const factor = 10 ** decimalPlaces;
  return Math.floor(num * factor) / factor;
}

/**
 * @dev Truncates the decimal part of a numeric string without routing it through a
 *      JavaScript number, which would produce scientific notation (1e-7) for very
 *      small or very large values.
 * @param value The decimal string, e.g. "0.000000123"
 * @param decimalPlaces How many decimal places to keep
 * @return The truncated decimal string
 */
export function truncateDecimalString(value: string, decimalPlaces: number): string {
  const [whole, decimal = ''] = value.split('.');
  const truncated = decimalPlaces > 0 ? decimal.slice(0, decimalPlaces).replace(/0+$/, '') : '';
  return truncated ? `${whole}.${truncated}` : whole;
}
