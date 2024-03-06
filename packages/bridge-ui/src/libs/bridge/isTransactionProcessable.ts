import { getBlock, readContract } from '@wagmi/core';
import { hexToBigInt } from 'viem';

import { crossChainSyncABI } from '$abi';
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

  // Any other status that's not NEW we assume this bridge tx
  // has already been processed (was processable)
  // TODO: do better job here as this is to make the UI happy

  if (status !== MessageStatus.NEW) return true;

  const destCrossChainSyncAddress = routingContractsMap[Number(destChainId)][Number(srcChainId)].crossChainSyncAddress;
  const srcChain = chains.find((chain) => chain.id === Number(srcChainId));

  if (!srcChain) return false;

  try {
    const { blockHash } = await readContract(config, {
      address: destCrossChainSyncAddress,
      abi: crossChainSyncABI,
      functionName: 'getSyncedSnippet',
      args: [BigInt(0)],
      chainId: Number(destChainId),
    });

    const srcBlock = await getBlock(config, {
      blockHash,
      chainId: Number(srcChainId),
    });

    return srcBlock.number !== null && hexToBigInt(receipt.blockNumber) <= srcBlock.number;
  } catch (error) {
    return false;
  }
}
