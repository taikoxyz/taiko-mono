import { readContract } from '@wagmi/core';
import { BaseError, ContractFunctionRevertedError, ContractFunctionZeroDataError } from 'viem';

import { bridgeAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { env } from '$env/dynamic/public';
import { RecallDisabledError, RecallStatusUnknownError } from '$libs/error';
import { config } from '$libs/wagmi';

import type { BridgeTransaction } from './types';

export type RecallState = 'enabled' | 'disabled' | 'unknown';

/**
 * Read the proxy each time: its implementation (and immutable) can change while the UI is open.
 * Only a missing getter on an otherwise responsive bridge may use the legacy recall behaviour.
 * A transport failure, malformed return or other revert is not evidence of a legacy bridge.
 */
export async function getRecallState(chainId: number, otherChainId: number): Promise<RecallState> {
  if (env.PUBLIC_BRIDGE_RECALL_ENABLED === 'false') return 'disabled';
  const address = routingContractsMap[chainId]?.[otherChainId]?.bridgeAddress;
  if (!address) return 'unknown';

  try {
    const enabled = await readContract(config, { address, abi: bridgeAbi, functionName: 'recallEnabled', chainId });
    return enabled === true ? 'enabled' : enabled === false ? 'disabled' : 'unknown';
  } catch (error) {
    if (!(error instanceof BaseError)) return 'unknown';
    const missingGetter = error.walk(
      (cause) =>
        cause instanceof ContractFunctionZeroDataError ||
        (cause instanceof ContractFunctionRevertedError &&
          !cause.data &&
          !cause.signature &&
          !cause.cause &&
          (!cause.reason || cause.reason === 'execution reverted')),
    );
    if (!missingGetter) return 'unknown';

    try {
      // Empty return data also occurs for an address without code. Verify a getter that both
      // old and new bridges implement before treating the address as a legacy bridge.
      const paused = await readContract(config, { address, abi: bridgeAbi, functionName: 'paused', chainId });
      return typeof paused === 'boolean' ? 'enabled' : 'unknown';
    } catch {
      return 'unknown';
    }
  }
}

/** A final retry can fail permanently only when the source can subsequently release the funds. */
export async function getFinalRetryState({
  srcChainId,
  destChainId,
}: Pick<BridgeTransaction, 'srcChainId' | 'destChainId'>): Promise<RecallState> {
  const states = await Promise.all([
    getRecallState(Number(srcChainId), Number(destChainId)),
    getRecallState(Number(destChainId), Number(srcChainId)),
  ]);
  if (states.includes('disabled')) return 'disabled';
  return states.every((state) => state === 'enabled') ? 'enabled' : 'unknown';
}

/** Check the source bridge before preparing a recall and again immediately before requesting a signature. */
export async function assertRecallEnabled({
  srcChainId,
  destChainId,
}: Pick<BridgeTransaction, 'srcChainId' | 'destChainId'>): Promise<void> {
  const state = await getRecallState(Number(srcChainId), Number(destChainId));
  if (state === 'disabled') throw new RecallDisabledError('Bridge recalls are disabled');
  if (state === 'unknown') throw new RecallStatusUnknownError('Could not determine bridge recall availability');
}
