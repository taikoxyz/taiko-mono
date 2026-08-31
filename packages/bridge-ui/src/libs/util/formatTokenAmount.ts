import { formatUnits } from 'viem';

/**
 * @dev Formats a raw token amount using the token's own decimals; ETH and tokens
 *      without known decimals fall back to 18.
 * @param amount The raw amount in the token's smallest unit
 * @param decimals The token's decimals
 * @return The human-readable amount
 */
export function formatTokenAmount(amount: Maybe<bigint>, decimals: Maybe<number> = 18): string {
  return formatUnits(amount ?? BigInt(0), decimals ?? 18);
}
