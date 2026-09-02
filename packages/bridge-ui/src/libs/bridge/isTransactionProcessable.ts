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
 * `null` is not a quieter `false`. It says the question could not be answered, which for this gate
 * means only one thing: the destination chain's synced height could not be read. `false` says the
 * claim cannot be made from this row as it stands - the destination has not synced the source block
 * yet, or the row carries nothing to prove against. Callers that only render a pending state may
 * treat the two alike, but anything offering the user an action must not: an action offered on a
 * `false` is one BridgeProver is about to reject.
 */
export type Processability = boolean | null;

export async function isTransactionProcessable(bridgeTx: BridgeTransaction): Promise<Processability> {
  const { message, srcChainId, destChainId, msgStatus } = bridgeTx;

  // Settled rather than unknown: every claim path throws on a missing message body, so there is
  // nothing here for the destination chain to sync towards.
  if (!message) return false;
  if (msgStatus !== MessageStatus.NEW) return true;

  // Settled for the same reason. A row with no readable source height is one BridgeProver rejects
  // outright with `Block number is not defined`, so no chain state can turn it into a claim that
  // works and no action may be offered on it. Waiting is the honest answer: the height is missing
  // because the transaction has not been mined and enhanced yet, and it arrives when it is.
  const srcBlockNumber = sourceBlockNumber(bridgeTx);
  if (srcBlockNumber === null) return false;

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
 *      Only `blockNumber`, because that is the single field BridgeProver reads, so this gate and
 *      the proof it gates agree on what "synced" means by construction. Reading the receipt as a
 *      second source would let this gate answer for a row the prover cannot prove. Nothing is lost
 *      by leaving it out: both producers of a receipt already copy its height into `blockNumber`
 *      (RelayerAPIService and BridgeTxService._enhanceTx), so a row with a receipt and no block
 *      number does not occur.
 *
 * @param bridgeTx The transaction to locate on its source chain
 * @return blockNumber_ The block the message was sent in, or null if the row does not say
 */
function sourceBlockNumber({ blockNumber }: BridgeTransaction): bigint | null {
  if (!blockNumber) return null;

  try {
    return BigInt(blockNumber);
  } catch {
    // A height in a shape BigInt cannot read is a height BridgeProver's own hexToBigInt cannot
    // read either, so the row is unprovable rather than merely unread
    log('Unreadable source block number', blockNumber);
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
