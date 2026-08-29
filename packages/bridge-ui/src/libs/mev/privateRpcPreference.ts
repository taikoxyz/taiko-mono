import { storageService } from '$config';

/**
 * There is no reliable way to ask a wallet which endpoint it broadcasts through, so we remember
 * that the user accepted the prompt and stop offering it again for that chain.
 */
const storageKey = (chainId: number) => `${storageService.mevProtectionPrefix}-${chainId}`;

/**
 * @param chainId The chain the claim will be sent to
 * @returns Whether the user has already added this chain's private relay to their wallet
 */
export function hasEnabledPrivateRpc(chainId: number): boolean {
  return globalThis.localStorage?.getItem(storageKey(chainId)) === 'true';
}

/**
 * @param chainId The chain whose private relay the wallet just accepted
 */
export function rememberEnabledPrivateRpc(chainId: number): void {
  globalThis.localStorage?.setItem(storageKey(chainId), 'true');
}
