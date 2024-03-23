import { readContract } from '@wagmi/core';

import { bridgeAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { config } from '$libs/wagmi';
import { bridgePausedModal } from '$stores/modal';

import { getLogger } from './logger';

const log = getLogger('bridge:checkForPausedContracts');

export const isBridgePaused = async () => {
  return await checkForPausedContracts();
};

export const checkForPausedContracts = async () => {
  const bridgeContractInfo = getConfiguredBridges();

  const pausedContracts = await Promise.all(
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
        //todo: will this ever happen and if so what do we do?
        // Right now we assume something is very off and we should stop the user from doing anything
        console.error('Error checking for paused contracts', error);

        return true;
      }
    }),
  );

  if (pausedContracts.some((isPaused) => isPaused)) {
    bridgePausedModal.set(true);
    return true;
  } else {
    bridgePausedModal.set(false);
    return false;
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
