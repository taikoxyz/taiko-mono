import { readContract } from '@wagmi/core';
import { keccak256, toBytes } from 'viem';

import { signalServiceAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { chains } from '$libs/chain';
import { config } from '$libs/wagmi';

import { type BridgeTransaction, MessageStatus } from './types';

export async function isTransactionProcessable(bridgeTx: BridgeTransaction) {
  const { receipt, message, srcChainId, destChainId, status } = bridgeTx;

  // Without these guys there is no way we can process this
  // bridge transaction. The receipt is needed in order to compare
  // the block number with the cross chain block number.
  if (!receipt || !message) return false;

  if (status !== MessageStatus.NEW) return true;

  const destCrossChainSyncAddress = routingContractsMap[Number(destChainId)][Number(srcChainId)].crossChainSyncAddress;
  const srcChain = chains.find((chain) => chain.id === Number(srcChainId));

  if (!srcChain) return false;

  try {
    const syncedChainData = await readContract(config, {
      address: destCrossChainSyncAddress,
      abi: signalServiceAbi,
      functionName: 'getSyncedChainData',
      args: [destChainId, keccak256(toBytes('STATE_ROOT')), 0n],
      chainId: Number(srcChainId),
    });

    const blockHeight = syncedChainData[0];
    return blockHeight !== null && receipt.blockNumber <= blockHeight;
  } catch (error) {
    return false;
  }
}
