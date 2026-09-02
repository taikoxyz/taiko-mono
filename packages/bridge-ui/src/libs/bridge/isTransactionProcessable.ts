import { getPublicClient, readContract } from '@wagmi/core';

import { signalServiceAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { isL2Chain } from '$libs/chain';
import { anchorGetBlockStateAbi, MAX_CHECKPOINT_SEARCH_BLOCKS } from '$libs/proof/constants';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { type BridgeTransaction, MessageStatus } from './types';

const log = getLogger('libs:bridge:isTransactionProcessable');

/**
 * Whether a transaction can be claimed, retried or released on the destination chain.
 *
 * `null` is not a quieter `false`. It says the question could not be answered - the synced height
 * could not be read, or the transaction does not carry a source block to compare it against -
 * whereas `false` asserts that the destination chain has not synced the source block yet. Callers
 * that only render a pending state may treat the two alike, but anything offering the user an
 * action must not: an action offered on a `false` is one BridgeProver is about to reject.
 */
export type Processability = boolean | null;

export async function isTransactionProcessable(bridgeTx: BridgeTransaction): Promise<Processability> {
  const { message, srcChainId, destChainId, msgStatus } = bridgeTx;

  // Settled rather than unknown: every claim path throws on a missing message body, so there is
  // nothing here for the destination chain to sync towards.
  if (!message) return false;
  if (msgStatus !== MessageStatus.NEW) return true;

  const srcBlockNumber = sourceBlockNumber(bridgeTx);
  if (srcBlockNumber === null) return null;

  try {
    const src = Number(srcChainId);
    const dest = Number(destChainId);
    const latestSyncedBlock = await getLatestSyncedBlock(src, dest);

    if (latestSyncedBlock === null) return null;

    const synced = latestSyncedBlock >= srcBlockNumber;
    log('isTransactionProcessable', { srcChainId, destChainId, srcBlockNumber, latestSyncedBlock, synced });
    return synced;
  } catch (error) {
    log('Could not determine whether the transaction is processable', error);
    return null;
  }
}

/**
 * @dev The source-chain height the destination has to have synced for this message to be provable.
 *
 *      `blockNumber` comes first because it is the field BridgeProver compares against, so this
 *      gate and the proof it gates agree on what "synced" means. The receipt is a fallback for
 *      rows that carry one without ever having been given a block number of their own.
 *
 * @param bridgeTx The transaction to locate on its source chain
 * @return blockNumber_ The block the message was sent in, or null if the row does not say
 */
function sourceBlockNumber({ blockNumber, receipt }: BridgeTransaction): bigint | null {
  const value = blockNumber ?? receipt?.blockNumber;
  if (!value) return null;

  try {
    return BigInt(value);
  } catch {
    // A relayer that reports the height in a shape BigInt cannot read leaves us without an
    // answer, which is not the same as the message not being synced
    log('Unreadable source block number', value);
    return null;
  }
}

/**
 * @dev Reads how far the destination chain has synced the source chain.
 *
 * @param srcChainId The chain the message was sent from
 * @param destChainId The chain the message is claimed on
 * @return blockNumber_ The latest synced source block, or null if it could not be established
 */
async function getLatestSyncedBlock(srcChainId: number, destChainId: number): Promise<bigint | null> {
  if (isL2Chain(destChainId)) {
    // L1->L2: query Anchor on L2
    const anchorAddress = routingContractsMap[destChainId][srcChainId].anchorForkRouter;
    if (!anchorAddress) return null;

    const blockState = await readContract(config, {
      address: anchorAddress,
      abi: anchorGetBlockStateAbi,
      functionName: 'getBlockState',
      chainId: destChainId,
    });
    return BigInt(blockState.anchorBlockNumber);
  }

  // L2->L1: query CheckpointSaved events on L1
  const destSignalService = routingContractsMap[destChainId][srcChainId].signalServiceAddress;
  const client = getPublicClient(config, { chainId: destChainId });
  if (!client) return null;

  const currentBlock = await client.getBlockNumber();
  const fromBlock = currentBlock > MAX_CHECKPOINT_SEARCH_BLOCKS ? currentBlock - MAX_CHECKPOINT_SEARCH_BLOCKS : 0n;
  const logs = await client.getContractEvents({
    address: destSignalService,
    abi: signalServiceAbi,
    eventName: 'CheckpointSaved',
    fromBlock,
    toBlock: currentBlock,
  });

  // The window is finite, so an empty result says the search found nothing, not that nothing exists
  if (logs.length === 0) return null;
  return BigInt(logs[logs.length - 1].args.blockNumber!);
}
