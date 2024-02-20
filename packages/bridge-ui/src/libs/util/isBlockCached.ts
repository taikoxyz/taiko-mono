import { getStorageAt } from '@wagmi/core';
import { type Address, encodePacked, type Hex,keccak256, toBytes, toHex } from 'viem';

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
  //TODO: query relayer, e.g. hasRelayerJustSentCachingTxnForThisBlock()

  const signalServiceAddress = routingContractsMap[destChainId][srcChainId].signalServiceAddress;
  const signal = getSignalForChainData(destChainId, blockNumber);
  const slot = getSignalSlot(destChainId, signalServiceAddress, signal);

  const signalRootValue = (await getStorageAt(config, {
    address: signalServiceAddress,
    chainId: destChainId,
    slot,
  })) as Hex;

  if (signalRootValue && signalRootValue !== toHex(0, { size: 32 })) {
    return true;
  }
  return false;
};

const getSignalForChainData = (chainId: number, blockId: number) => {
  return keccak256(encodePacked(['uint64', 'bytes32', 'uint64'], [BigInt(chainId), SIGNAL_ROOT, BigInt(blockId)]));
};

const getSignalSlot = (chainId: number, app: Address, signal: Hex) => {
  return keccak256(encodePacked(['string', 'uint64', 'address', 'bytes32'], ['SIGNAL', BigInt(chainId), app, signal]));
};
