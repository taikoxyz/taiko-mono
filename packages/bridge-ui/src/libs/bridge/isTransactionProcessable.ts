import { getPublicClient, readContract } from '@wagmi/core';

import { signalServiceAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { isL2Chain } from '$libs/chain';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { type BridgeTransaction, MessageStatus } from './types';

const log = getLogger('libs:bridge:isTransactionProcessable');

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

export async function isTransactionProcessable(bridgeTx: BridgeTransaction) {
  const { receipt, message, srcChainId, destChainId, msgStatus } = bridgeTx;

  if (!receipt || !message) return false;

  // Any other status that's not NEW we assume this bridge tx
  // has already been processed (was processable)
  if (msgStatus !== MessageStatus.NEW) return true;

  try {
    let latestSyncedBlock: bigint;

    if (isL2Chain(Number(destChainId))) {
      // L1→L2: Query Anchor on L2 for latest synced L1 block
      const anchorAddress = routingContractsMap[Number(destChainId)][Number(srcChainId)].anchorForkRouter;
      if (!anchorAddress) return false;

      const blockState = await readContract(config, {
        address: anchorAddress,
        abi: anchorGetBlockStateAbi,
        functionName: 'getBlockState',
        chainId: Number(destChainId),
      });

      latestSyncedBlock = BigInt(blockState.anchorBlockNumber);
    } else {
      // L2→L1: Query latest CheckpointSaved event on L1 SignalService
      const destSignalServiceAddress =
        routingContractsMap[Number(destChainId)][Number(srcChainId)].signalServiceAddress;

      const destClient = getPublicClient(config, { chainId: Number(destChainId) });
      if (!destClient) return false;

      const currentBlock = await destClient.getBlockNumber();
      const fromBlock = currentBlock > 10000n ? currentBlock - 10000n : 0n;
      const logs = await destClient.getContractEvents({
        address: destSignalServiceAddress,
        abi: signalServiceAbi,
        eventName: 'CheckpointSaved',
        fromBlock,
        toBlock: currentBlock,
      });

      if (logs.length === 0) return false;

      latestSyncedBlock = BigInt(logs[logs.length - 1].args.blockNumber!);
    }

    const synced = latestSyncedBlock >= receipt.blockNumber;

    log('isTransactionProcessable', {
      from: srcChainId,
      to: destChainId,
      latestSyncedBlock,
      receiptBlockNumber: receipt.blockNumber,
      synced,
    });

    return synced;
  } catch (error) {
    console.error('Error checking if transaction is processable', error);
    return false;
  }
}
