import { readContract } from '@wagmi/core';
import { zeroHash } from 'viem';

import { signalServiceAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { config } from '$libs/wagmi';

export const isBlockCached = async ({
  srcChainId,
  destChainId,
  blockNumber,
}: {
  srcChainId: number;
  destChainId: number;
  blockNumber: bigint;
}) => {
  const signalServiceAddress = routingContractsMap[destChainId][srcChainId].signalServiceAddress;

  try {
    const checkpoint = await readContract(config, {
      address: signalServiceAddress,
      abi: signalServiceAbi,
      functionName: 'getCheckpoint',
      args: [Number(blockNumber)],
      chainId: destChainId,
    });

    return checkpoint.stateRoot !== zeroHash;
  } catch (error) {
    console.error('Error checking if block is cached', error);
  }
  return false;
};
