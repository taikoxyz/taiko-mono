import { getPublicClient, readContract } from '@wagmi/core';
import { keccak256, toBytes } from 'viem';

import { pacayaSignalServiceAbi, signalServiceAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { isL2Chain } from '$libs/chain';
import { getProtocolVersion, ProtocolVersion } from '$libs/protocol/protocolVersion';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { type BridgeTransaction, MessageStatus } from './types';

const log = getLogger('libs:bridge:isTransactionProcessable');

const MAX_CHECKPOINT_SEARCH_BLOCKS = 10000n;

const anchorGetBlockStateAbi = [
  {
    type: 'function',
    name: 'getBlockState',
    inputs: [],
    outputs: [
      {
        type: 'tuple',
        components: [
          { name: 'anchorBlockNumber', type: 'uint48' },
          { name: 'ancestorsHash', type: 'bytes32' },
        ],
      },
    ],
    stateMutability: 'view',
  },
] as const;

export async function isTransactionProcessable(bridgeTx: BridgeTransaction): Promise<boolean> {
  const { receipt, message, srcChainId, destChainId, msgStatus } = bridgeTx;

  if (!receipt || !message || !receipt.blockNumber) return false;
  if (msgStatus !== MessageStatus.NEW) return true;

  try {
    const src = Number(srcChainId);
    const dest = Number(destChainId);
    const protocol = await getProtocolVersion(src, dest);
    const latestSyncedBlock =
      protocol === ProtocolVersion.PACAYA
        ? await getLatestSyncedBlockPacaya(src, dest)
        : await getLatestSyncedBlockShasta(src, dest);

    if (latestSyncedBlock === null) return false;

    const synced = latestSyncedBlock >= receipt.blockNumber;
    log('isTransactionProcessable', { protocol, srcChainId, destChainId, latestSyncedBlock, synced });
    return synced;
  } catch (error) {
    log('Error checking if transaction is processable', error);
    return false;
  }
}

async function getLatestSyncedBlockPacaya(srcChainId: number, destChainId: number): Promise<bigint | null> {
  try {
    const destSignalService = routingContractsMap[destChainId]?.[srcChainId]?.signalServiceAddress;
    if (!destSignalService) return null;

    const result = await readContract(config, {
      address: destSignalService,
      abi: pacayaSignalServiceAbi,
      functionName: 'getSyncedChainData',
      args: [BigInt(srcChainId), keccak256(toBytes('STATE_ROOT')), 0n],
      chainId: destChainId,
    });
    return result[0];
  } catch {
    return null;
  }
}

async function getLatestSyncedBlockShasta(srcChainId: number, destChainId: number): Promise<bigint | null> {
  if (isL2Chain(destChainId)) {
    // L1→L2: query Anchor on L2
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

  // L2→L1: query CheckpointSaved events on L1
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

  if (logs.length === 0) return null;
  return BigInt(logs[logs.length - 1].args.blockNumber!);
}
