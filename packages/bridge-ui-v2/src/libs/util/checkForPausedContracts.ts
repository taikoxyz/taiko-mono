import { getContract } from '@wagmi/core';

import { bridgeABI } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { bridgePausedModal } from '$stores/modal';

export const isBridgePaused = async () => {
  await checkForPausedContracts();
  if (bridgePausedModal) {
    return true;
  }
  return false;
};

export const checkForPausedContracts = async () => {
  const bridgeContractInfo = getConfiguredBridges();

  const pausedContracts = await Promise.all(
    bridgeContractInfo.map(async (bridgeInfo) => {
      const { srcChainId, bridgeAddress } = bridgeInfo;

      try {
        const contract = getContract({
          chainId: srcChainId,
          abi: bridgeABI,
          address: bridgeAddress,
        });

        const paused = await contract.read.paused();

        if (paused) {
          return true;
        }
      } catch {
        return true;
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
