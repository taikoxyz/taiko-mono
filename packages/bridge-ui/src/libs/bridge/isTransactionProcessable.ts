import { chains } from '$libs/chain';
import { getFirstAvailableBlockInfo } from '$libs/relayer/getFirstAvailableBlockInfo';

import { type BridgeTransaction, MessageStatus } from './types';

export async function isTransactionProcessable(bridgeTx: BridgeTransaction) {
  const { receipt, message, srcChainId, status } = bridgeTx;

  // Without these guys there is no way we can process this
  // bridge transaction. The receipt is needed in order to compare
  // the block number with the cross chain block number.
  if (!receipt || !message) return false;

  if (status !== MessageStatus.NEW) return true;

  const srcChain = chains.find((chain) => chain.id === Number(srcChainId));

  if (!srcChain) return false;

  const syncedInfo = await getFirstAvailableBlockInfo(Number(srcChainId));
  if (!syncedInfo) return false;
  const { latestBlock } = syncedInfo;
  return latestBlock !== null && receipt.blockNumber <= latestBlock;
}
