import { getContract } from '@wagmi/core';

import { crossChainSyncABI } from '$abi';
import { chainContractsMap } from '$libs/chain';
import { publicClient } from '$libs/wagmi';

import { type BridgeTransaction, MessageStatus } from './types';

export async function isBridgeTxProcessable(bridgeTx: BridgeTransaction) {
  const { receipt, message, status, srcChainId, destChainId } = bridgeTx;

  // Without these guys there is no way we can process this
  // bridge transaction. The receipt is needed in order to compare
  // the block number with the cross chain block number.
  if (!receipt || !message) return false;

  // TODO: Not sure this could ever happens. When we add the
  // transaction to the local storage, we don't set the status,
  // but when we fetch them, then we query the contract for this status.
  if (status !== MessageStatus.NEW) return true;

  const destCrossChainSyncAddress = chainContractsMap[Number(destChainId)].crossChainSyncAddress;

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

    return srcBlock.number && receipt.blockNumber <= srcBlock.number;
  } catch (error) {
    return false;
  }
}
