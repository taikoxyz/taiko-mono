import { readContract } from '@wagmi/core';
import type { Address } from 'viem';

import { bridgeAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import type { BridgeTransaction } from './types';

const log = getLogger('libs:bridge:recallAvailability');

export type RecallBridgeSide = 'source' | 'destination';

/**
 * Reads the bridge implementation's recall switch. Unknown availability is treated as disabled:
 * a stale UI must not submit a recall or a last-attempt retry when the safety switch cannot be
 * verified.
 */
export async function isRecallEnabled(chainId: number, bridgeAddress: Address): Promise<boolean> {
  try {
    return await readContract(config, {
      address: bridgeAddress,
      abi: bridgeAbi,
      functionName: 'recallEnabled',
      chainId,
    });
  } catch (error) {
    log('Could not read bridge recall availability', { chainId, bridgeAddress, error });
    return false;
  }
}

/** Reads the recall switch on the source or destination bridge for a stored transaction. */
export async function isTransactionRecallEnabled(
  bridgeTx: BridgeTransaction,
  side: RecallBridgeSide,
): Promise<boolean> {
  const { message } = bridgeTx;
  if (!message) return false;

  const srcChainId = Number(message.srcChainId);
  const destChainId = Number(message.destChainId);
  const chainId = side === 'source' ? srcChainId : destChainId;
  const peerChainId = side === 'source' ? destChainId : srcChainId;
  const bridgeAddress = routingContractsMap[chainId]?.[peerChainId]?.bridgeAddress;
  if (!bridgeAddress) return false;

  return isRecallEnabled(chainId, bridgeAddress);
}
