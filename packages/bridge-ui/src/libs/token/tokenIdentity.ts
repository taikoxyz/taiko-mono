import { zeroAddress } from 'viem';

import type { NFT, Token } from './types';

/**
 * @dev A token's identity is its set of chain-qualified deployments; symbols are not
 *      unique, and the same hexadecimal address can host unrelated tokens on
 *      different chains.
 * @param token The token
 * @return One "chainId:address" key per real deployment
 */
export function tokenDeploymentKeys(token: Token | NFT): string[] {
  return Object.entries(token.addresses ?? {})
    .filter(([, address]) => address && address !== zeroAddress)
    .map(([chainId, address]) => `${chainId}:${address.toLowerCase()}`);
}

/**
 * @dev Two tokens are the same token if they share any chain-qualified deployment; the
 *      symbol is only a fallback for entries that carry no addresses at all.
 *
 *      One side having deployments and the other having none is not a match. Symbols are
 *      not unique, and this decides whether storeToken suppresses an entry and which entry
 *      removeToken deletes - so an identity that cannot be established should answer "not
 *      the same" rather than act on a guess.
 *
 * @param a The first token
 * @param b The second token
 * @return Whether both describe the same token
 */
export function tokensAreSame(a: Token | NFT, b: Token | NFT): boolean {
  const aKeys = tokenDeploymentKeys(a);
  const bKeys = new Set(tokenDeploymentKeys(b));

  if (aKeys.length > 0 || bKeys.size > 0) {
    return aKeys.some((key) => bKeys.has(key));
  }
  return a.symbol === b.symbol;
}

/**
 * @dev A stable, unique key for rendering token lists that may contain
 *      distinct tokens sharing a symbol.
 * @param token The token
 * @return The identity key
 */
export function tokenIdentityKey(token: Token | NFT): string {
  const keys = tokenDeploymentKeys(token);
  return keys.length > 0 ? `${token.symbol}|${keys.join('|')}` : token.symbol;
}
