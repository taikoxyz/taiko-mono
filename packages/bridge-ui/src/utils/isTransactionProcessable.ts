import { Contract } from 'ethers';
import HeaderSyncABI from '../constants/abi/HeaderSync';
import { chains } from '../chain/chains';
import { MessageStatus } from '../domain/message';
import type { BridgeTransaction } from '../domain/transaction';
import { providers } from '../provider/providers';

// TODO: explain and unit test
export async function isTransactionProcessable(transaction: BridgeTransaction) {
  const { receipt, message, status } = transaction;

  if (!receipt || !message) return false;

  if (status !== MessageStatus.New) return true;

  const headerSyncContract = new Contract(
    chains[transaction.toChainId].headerSyncAddress,
    HeaderSyncABI,
    providers[transaction.toChainId],
  );

  const latestSyncedHeader = await headerSyncContract.getLatestSyncedHeader();
  const srcBlock = await providers[chains[transaction.fromChainId].id].getBlock(
    latestSyncedHeader,
  );

  return receipt.blockNumber <= srcBlock.number;
}
