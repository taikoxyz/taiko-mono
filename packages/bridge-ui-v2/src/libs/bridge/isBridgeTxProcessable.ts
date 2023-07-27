import { chainContractsMap } from "$libs/chain";
import { getContract } from "@wagmi/core";
import { MessageStatus, type BridgeTransaction } from "./types";
import { crossChainSyncABI } from "$abi";
import { publicClient } from "$libs/wagmi";

export async function isBridgeTxProcessable(bridgeTx: BridgeTransaction) {
  const { receipt, message, status, srcChainId, destChainId } = bridgeTx;
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

    const blockHash = await destCrossChainSyncContract.read.getCrossChainBlockHash([0]);

    const srcBlock = await publicClient({ chainId: Number(srcChainId) }).getBlock({
      blockHash,
    });

    return srcBlock.number && receipt.blockNumber <= srcBlock.number;
  } catch (error) {
    return false;
  }
}
