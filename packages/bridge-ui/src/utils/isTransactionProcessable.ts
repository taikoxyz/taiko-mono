import { Contract } from 'ethers';

import { chains } from '../chain/chains';
import { crossChainSyncABI } from '../constants/abi';
import { MessageStatus } from '../domain/message';
import type { BridgeTransaction } from '../domain/transaction';
import { providers } from '../provider/providers';

export async function isTransactionProcessable(transaction: BridgeTransaction) {
  const { receipt, message, status, srcChainId, destChainId } = transaction;
  if (!receipt || !message) return false;

  if (status !== MessageStatus.New) return true;

  const destChain = chains[destChainId];
  const srcProvider = providers[srcChainId];
  const destProvider = providers[destChainId];

  try {
    const destCrossChainSyncContract = new Contract(
      destChain.crossChainSyncAddress,
      crossChainSyncABI,
      destProvider,
    );

    const blockHash = await destCrossChainSyncContract.getCrossChainBlockHash(
      0,
    );

    const srcBlock = await srcProvider.getBlock(blockHash);

    return receipt.blockNumber <= srcBlock.number;
  } catch (error) {
    console.error(error);
    return false;
  }
}
