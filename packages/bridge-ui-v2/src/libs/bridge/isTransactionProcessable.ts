import { getContract } from '@wagmi/core';

import { crossChainSyncABI } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { publicClient } from '$libs/wagmi';

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

  try {
    const destCrossChainSyncContract = getContract({
      address: destCrossChainSyncAddress,
      abi: crossChainSyncABI,
      chainId: Number(destChainId),
    });

    const blockHash = await destCrossChainSyncContract.read.getCrossChainBlockHash([BigInt(0)]);

    const srcBlock = await publicClient({ chainId: Number(srcChainId) }).getBlock({
      blockHash,
    });

    return srcBlock.number !== null && receipt.blockNumber <= srcBlock.number;
  } catch (error) {
    return false;
  }
}
