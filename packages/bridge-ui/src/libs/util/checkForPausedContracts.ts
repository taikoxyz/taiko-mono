import { readContract } from '@wagmi/core';

import { bridgeAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { config } from '$libs/wagmi';
import { bridgePausedModal } from '$stores/modal';

import { getLogger } from './logger';

const log = getLogger('bridge:checkForPausedContracts');

/** A `paused()` read that threw: the contract's state is unknown, not paused. */
const UNKNOWN = 'unknown';

/**
 * @dev Reports whether a bridge contract is paused.
 * @param srcChainId Restricts the check to the bridge that sends from this chain. Omit to
 *                   check every configured bridge, which is what the global paused modal
 *                   is driven off.
 * @return paused_ Whether a bridge that could be read reports itself paused
 */
export const isBridgePaused = async (srcChainId?: number) => {
  return await checkForPausedContracts(srcChainId);
};

export const checkForPausedContracts = async (srcChainId?: number) => {
  const bridgeContractInfo = getConfiguredBridges(srcChainId);

  const states = await Promise.all(
    bridgeContractInfo.map(async (bridgeInfo) => {
      const { srcChainId, bridgeAddress } = bridgeInfo;
      log(`Checking if bridge ${bridgeAddress} is paused on chain ${srcChainId}`);
      try {
        return await readContract(config, {
          abi: bridgeAbi,
          address: bridgeAddress,
          chainId: srcChainId,
          functionName: 'paused',
        });
      } catch (error) {
        // An unreachable RPC says nothing about the contract. Reporting it as paused
        // blocked every bridge action on a single transient error, and the block bought
        // nothing: sendMessage and processMessage are `whenNotPaused` on chain, so a
        // genuinely paused bridge rejects the transaction regardless of what this read did.
        console.error('Error checking for paused contracts', error);
        return UNKNOWN;
      }
    }),
  );

  // One chain reporting itself paused settles it, whatever the others did
  if (states.some((state) => state === true)) {
    bridgePausedModal.set(true);
    return true;
  }

  // Clearing the modal is an assertion that nothing is paused, so it takes complete
  // information. A chain that could not be read might be the paused one - dismissing a
  // real pause because the *other* chains answered false is the failure this avoids, and
  // it covers the all-unknown case as the same rule rather than a special one.
  //
  // Only the unscoped sweep may clear it. A scoped check speaks for one chain, so letting it
  // clear the modal dismissed a warning the sweep had raised for a different chain that is
  // genuinely paused - and the send paths call the scoped one on every attempt.
  if (srcChainId === undefined && !states.includes(UNKNOWN)) {
    bridgePausedModal.set(false);
  }
  return false;
};

function getConfiguredBridges(srcChainId?: number) {
  const bridges = [];
  // The same bridge address is configured once per destination chain; reading it once per
  // pair multiplied the RPC calls by the number of destinations for no extra information
  const seen = new Set<string>();

  for (const configuredSrcChainId in routingContractsMap) {
    const chainId = parseInt(configuredSrcChainId);
    if (srcChainId !== undefined && chainId !== srcChainId) continue;

    for (const destChainId in routingContractsMap[configuredSrcChainId]) {
      const bridgeAddress = routingContractsMap[configuredSrcChainId][destChainId].bridgeAddress;
      const key = `${chainId}:${bridgeAddress.toLowerCase()}`;
      if (seen.has(key)) continue;
      seen.add(key);

      bridges.push({ srcChainId: chainId, bridgeAddress });
    }
  }

  return bridges;
}
