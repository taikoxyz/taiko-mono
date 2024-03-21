import { readContract } from '@wagmi/core';
import { keccak256, toBytes } from 'viem';

import { signalServiceAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { chains } from '$libs/chain';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { type BridgeTransaction, MessageStatus } from './types';
const log = getLogger('libs:bridge:isTransactionProcessable');

export async function isTransactionProcessable(bridgeTx: BridgeTransaction) {
  const { receipt, message, srcChainId, destChainId, msgStatus } = bridgeTx;

  // Without these guys there is no way we can process this
  // bridge transaction. The receipt is needed in order to compare
  // the block number with the cross chain block number.
  if (!receipt || !message) return false;

  // Any other status that's not NEW we assume this bridge tx
  // has already been processed (was processable)
  // TODO: do better job here as this is to make the UI happy

  if (msgStatus !== MessageStatus.NEW) return true;

  const destSignalServiceAddress = routingContractsMap[Number(destChainId)][Number(srcChainId)].signalServiceAddress;
  const srcChain = chains.find((chain) => chain.id === Number(srcChainId));

  if (!srcChain) return false;

  try {
    const syncedChainData = await readContract(config, {
      address: destSignalServiceAddress,
      abi: signalServiceAbi,
      functionName: 'getSyncedChainData',
      args: [srcChainId, keccak256(toBytes('STATE_ROOT')), 0n],
      chainId: Number(destChainId),
    });

    const latestSyncedblock = syncedChainData[0];

    const synced = latestSyncedblock >= receipt.blockNumber;

    log('isTransactionProcessable', {
      from: srcChainId,
      to: destChainId,
      latestSyncedblock,
      receiptBlockNumber: receipt.blockNumber,
      synced,
    });

    return synced;
  } catch (error) {
    console.error('Error checking if transaction is processable', error);
    return false;
  }
}
