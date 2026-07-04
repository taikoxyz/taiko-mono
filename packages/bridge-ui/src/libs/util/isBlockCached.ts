import { readContract } from '@wagmi/core';
import { keccak256, toBytes } from 'viem';

import { signalServiceAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { config } from '$libs/wagmi';

const SIGNAL_ROOT = keccak256(toBytes('SIGNAL_ROOT'));

export const isBlockCached = async ({
  srcChainId,
  destChainId,
  blockNumber,
}: {
  srcChainId: number;
  destChainId: number;
  blockNumber: bigint;
}) => {
  const signalServiceAddress = routingContractsMap[srcChainId][destChainId].signalServiceAddress;

  try {
    const latestCachedBlock = await readContract(config, {
      address: signalServiceAddress,
      abi: signalServiceAbi,
      functionName: 'getSyncedChainData',
      args: [BigInt(destChainId), SIGNAL_ROOT, 0n],
    });

    return latestCachedBlock[0] >= blockNumber;
  } catch (error) {
    console.error('Error checking if block is cached', error);
  }
  return false;
};
