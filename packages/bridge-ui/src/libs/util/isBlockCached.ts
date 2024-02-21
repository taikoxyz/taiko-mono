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
  blockNumber: number;
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

//   const signal = getSignalForChainData(destChainId, blockNumber);
//   const slot = getSignalSlot(destChainId, signalServiceAddress, signal);

//   const signalRootValue = (await getStorageAt(config, {
//     address: signalServiceAddress,
//     chainId: destChainId,
//     slot,
//   })) as Hex;

//   if (signalRootValue && signalRootValue !== toHex(0, { size: 32 })) {
//     return true;
//   }
//   return false;
// };

// const getSignalForChainData = (chainId: number, blockId: number) => {
//   return keccak256(encodePacked(['uint64', 'bytes32', 'uint64'], [BigInt(chainId), SIGNAL_ROOT, BigInt(blockId)]));
// };

// const getSignalSlot = (chainId: number, app: Address, signal: Hex) => {
//   return keccak256(encodePacked(['string', 'uint64', 'address', 'bytes32'], ['SIGNAL', BigInt(chainId), app, signal]));
// };
