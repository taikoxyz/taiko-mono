import { getPublicClient } from '@wagmi/core';
import { get } from 'svelte/store';
import { getContract } from 'viem';

import { bridgeABI } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { config } from '$libs/wagmi';
import { bridgePausedModal } from '$stores/modal';

import { getLogger } from './logger';

const log = getLogger('bridge:checkForPausedContracts');

export const isBridgePaused = async () => {
  await checkForPausedContracts();
  if (get(bridgePausedModal)) {
    return true;
  }
  return false;
};

export const checkForPausedContracts = async () => {
  const bridgeContractInfo = getConfiguredBridges();

  const pausedContracts = await Promise.all(
    bridgeContractInfo.map(async (bridgeInfo) => {
      const { srcChainId, bridgeAddress } = bridgeInfo;

      const client = getPublicClient(config, {
        chainId: srcChainId,
      });
      if (!client) return;
      try {
        const contract = getContract({
          client,
          abi: bridgeABI,
          address: bridgeAddress,
        });

        const paused = await contract.read.paused();

        if (paused) {
          return true;
        }
      } catch {
        //todo: will this ever happen and if so what do we do?
        log('Error checking for paused contracts');
      }
    }),
  );

  if (pausedContracts.some((isPaused) => isPaused)) {
    bridgePausedModal.set(true);
  } else {
    bridgePausedModal.set(false);
  }
};

function getConfiguredBridges() {
  const bridges = [];

  for (const srcChainId in routingContractsMap) {
    for (const destChainId in routingContractsMap[srcChainId]) {
      const bridgeAddress = routingContractsMap[srcChainId][destChainId].bridgeAddress;
      bridges.push({
        srcChainId: parseInt(srcChainId),
        destChainId: parseInt(destChainId),
        bridgeAddress: bridgeAddress,
      });
    }
  }

  return bridges;
}
