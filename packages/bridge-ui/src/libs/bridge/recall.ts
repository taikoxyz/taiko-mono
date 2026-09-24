import { getPublicClient, readContract } from '@wagmi/core';
import { type Address, BaseError, decodeFunctionResult, encodeFunctionData, RpcRequestError } from 'viem';

import { bridgeAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { env } from '$env/dynamic/public';
import { RecallDisabledError, RecallStatusUnknownError } from '$libs/error';
import { config } from '$libs/wagmi';

import type { BridgeTransaction } from './types';

export type RecallState = 'enabled' | 'disabled' | 'unknown';
type RecallReadOptions = { fresh?: boolean };

const pendingRecallReads = new Map<string, Promise<RecallState>>();

/**
 * Share concurrent UI reads, but discard settled results: the proxy implementation can change.
 * Only a missing getter on an otherwise responsive bridge may use the legacy recall behaviour.
 * A transport failure, malformed return or other revert is not evidence of a legacy bridge.
 */
export async function getRecallState(
  chainId: number,
  otherChainId: number,
  options: RecallReadOptions = {},
): Promise<RecallState> {
  const flag = env.PUBLIC_BRIDGE_RECALL_ENABLED?.trim().toLowerCase();
  if (flag && flag !== 'true') return 'disabled';
  const address = routingContractsMap[chainId]?.[otherChainId]?.bridgeAddress;
  if (!address) return 'unknown';
  // Transaction guards must not wait on an earlier UI read taken before a possible upgrade.
  if (options.fresh) return readRecallState(chainId, address);

  const key = `${chainId}:${address.toLowerCase()}`;
  const pending = pendingRecallReads.get(key);
  if (pending) return pending;
  const read = readRecallState(chainId, address).finally(() => pendingRecallReads.delete(key));
  pendingRecallReads.set(key, read);
  return read;
}

async function readRecallState(chainId: number, address: Address): Promise<RecallState> {
  try {
    const client = getPublicClient(config, { chainId });
    if (!client) return 'unknown';
    // Read the raw RPC result: readContract can discard nested revert data, and call
    // conflates a missing result with "0x". Only a literal empty result is a legacy hint.
    const data = await client.request({
      method: 'eth_call',
      params: [{ to: address, data: encodeFunctionData({ abi: bridgeAbi, functionName: 'recallEnabled' }) }, 'latest'],
    });
    if (typeof data !== 'string') return 'unknown';
    if (data !== '0x') {
      const enabled = decodeFunctionResult({ abi: bridgeAbi, functionName: 'recallEnabled', data });
      return enabled === true ? 'enabled' : enabled === false ? 'disabled' : 'unknown';
    }
  } catch (error) {
    if (!(error instanceof BaseError)) return 'unknown';
    const missingGetter = error.walk((cause) => {
      // Clients differ in code and casing; require a bare revert with no error data.
      if (!(cause instanceof RpcRequestError) || ![3, -32000].includes(cause.code)) return false;
      const rpcError = cause.cause;
      return (
        typeof rpcError === 'object' &&
        rpcError !== null &&
        'message' in rpcError &&
        typeof rpcError.message === 'string' &&
        rpcError.message.toLowerCase() === 'execution reverted' &&
        (!('data' in rpcError) || rpcError.data == null || rpcError.data === '0x')
      );
    });
    if (!missingGetter) return 'unknown';
  }

  try {
    // Empty return data also occurs for an address without code. Verify a getter that both
    // old and new bridges implement before treating the address as a legacy bridge.
    const paused = await readContract(config, { address, abi: bridgeAbi, functionName: 'paused', chainId });
    return typeof paused === 'boolean' ? 'enabled' : 'unknown';
  } catch {
    return 'unknown';
  }
}

/** A final retry can fail permanently only when the source can subsequently release the funds. */
export async function getFinalRetryState(
  { srcChainId, destChainId }: Pick<BridgeTransaction, 'srcChainId' | 'destChainId'>,
  options: RecallReadOptions = {},
): Promise<RecallState> {
  const states = await Promise.all([
    getRecallState(Number(srcChainId), Number(destChainId), options),
    getRecallState(Number(destChainId), Number(srcChainId), options),
  ]);
  if (states.includes('disabled')) return 'disabled';
  return states.every((state) => state === 'enabled') ? 'enabled' : 'unknown';
}

/** Check the source bridge before preparing a recall and again immediately before requesting a signature. */
export async function assertRecallEnabled({
  srcChainId,
  destChainId,
}: Pick<BridgeTransaction, 'srcChainId' | 'destChainId'>): Promise<void> {
  assertRecallStateEnabled(await getRecallState(Number(srcChainId), Number(destChainId), { fresh: true }));
}

/** Preserve the requested retry type: unavailable final retries must not silently become ordinary ones. */
export async function assertFinalRetryEnabled(
  message: Pick<BridgeTransaction, 'srcChainId' | 'destChainId'>,
): Promise<void> {
  assertRecallStateEnabled(await getFinalRetryState(message, { fresh: true }));
}

function assertRecallStateEnabled(state: RecallState): void {
  if (state === 'disabled') throw new RecallDisabledError('Bridge recalls are disabled');
  if (state === 'unknown') throw new RecallStatusUnknownError('Could not determine bridge recall availability');
}
