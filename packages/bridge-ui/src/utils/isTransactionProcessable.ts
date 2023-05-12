import { Contract } from 'ethers';
import { MessageStatus } from '../domain/message';
import type { BridgeTransaction } from '../domain/transactions';
import { chains } from '../chain/chains';
import { providers } from '../provider/providers';
import { crossChainSyncABI } from '../constants/abi';
import { getLogger } from './logger';

const log = getLogger('util:isTransactionProcessable');

export async function isTransactionProcessable(transaction: BridgeTransaction) {
  const { receipt, message, status, fromChainId, toChainId } = transaction;
  if (!receipt || !message) return false;

  if (status !== MessageStatus.New) return true;

  const destChain = chains[toChainId];
  const srcProvider = providers[fromChainId];
  const destProvider = providers[toChainId];

  try {
    const crossChainSyncContract = new Contract(
      destChain.crossChainSyncAddress,
      crossChainSyncABI,
      destProvider,
    );

    const blockHash = await crossChainSyncContract.getCrossChainBlockHash(0);

    const srcBlock = await srcProvider.getBlock(blockHash);

    return receipt.blockNumber <= srcBlock.number;
  } catch (error) {
    console.error(error);
    return false;
  }
}
