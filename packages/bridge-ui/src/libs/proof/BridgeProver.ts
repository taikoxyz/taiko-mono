import { getPublicClient, readContract } from '@wagmi/core';
import {
  type Address,
  BlockNotFoundError,
  encodeAbiParameters,
  encodePacked,
  type Hex,
  keccak256,
  numberToHex,
  toBytes,
  toHex,
} from 'viem';

import { signalServiceAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import type { BridgeTransaction } from '$libs/bridge';
import { BlockError, ClientError, ProofGenerationError } from '$libs/error';
import { getFirstAvailableBlockInfo } from '$libs/relayer/getFirstAvailableBlockInfo';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import type { ClientWithEthGetProofRequest, GetProofArgs, HopProof } from './types';

const log = getLogger('proof:Prover');

type AbiParameter = {
  type: string;
  name: string;
  components?: AbiParameter[]; // Optional, for nested structures like 'tuple[]'
};

export class BridgeProver {
  async getSignalSlot(chainId: number, contractAddress: Address, msgHash: Hex) {
    return keccak256(
      encodePacked(['string', 'uint64', 'address', 'bytes32'], ['SIGNAL', BigInt(chainId), contractAddress, msgHash]),
    );
  }

  async getEncodedSignalProof({ bridgeTx }: { bridgeTx: BridgeTransaction }) {
    const { blockNumber, message, msgHash } = bridgeTx;
    log('msgHash', msgHash);
    if (!message) throw new ProofGenerationError('Message is not defined');
    const { srcChainId, destChainId } = message;

    let previousSrcChainId = srcChainId; // Initialize with the original source chain ID
    const key = await this.getSignalSlot(
      Number(srcChainId),
      routingContractsMap[Number(srcChainId)][Number(destChainId)].bridgeAddress,
      msgHash,
    );
    const configuredHops = routingContractsMap[Number(srcChainId)][Number(destChainId)].hops;

    if (configuredHops && configuredHops.length > 0) {
      const hopProofs: HopProof[] = [];

      for (let i = 0; i < configuredHops.length; i++) {
        const currentHop = configuredHops[i];
        let currentSignalServiceAddress: Address;

        if (i + 1 < configuredHops.length) {
          // There is a next hop
          currentSignalServiceAddress = configuredHops[i + 1].signalServiceAddress;
        } else {
          // This is the last hop, so use the destination's signal service address
          currentSignalServiceAddress =
            routingContractsMap[Number(destChainId)][Number(srcChainId)].signalServiceAddress;
        }

        // const syncedChainData = await readContract(config, {
        //   address: currentSignalServiceAddress,
        //   abi: signalServiceAbi,
        //   functionName: 'getSyncedChainData',
        //   args: [BigInt(destChainId), keccak256(toBytes('STATE_ROOT')), 0n],
        //   chainId: Number(previousSrcChainId),
        // });

        const latestBlockNumber = await this.getLatestSrcBlockNumber(previousSrcChainId, destChainId);

        const hopClient = getPublicClient(config, { chainId: Number(currentHop.chainId) });
        if (!hopClient) throw new Error('Could not get public client');

        const block = await hopClient.getBlock({ blockNumber: latestBlockNumber });
        if (block.hash === null || block.number === null) {
          throw new BlockNotFoundError({ blockHash: block.hash, blockNumber: block.number });
        }
        if (latestBlockNumber < block.number) {
          //TODO handle this earlier somehow
          throw new Error('block is not synced yet');
        }

        const clientWithEthProofRequest = hopClient as ClientWithEthGetProofRequest;
        const hopProof = await clientWithEthProofRequest.request({
          method: 'eth_getProof',
          params: [currentSignalServiceAddress, [key], numberToHex(latestBlockNumber as bigint)],
        });
        log('Proof from eth_getProof', hopProof);

        //TODO check for caching then do the following if cached
        // hopProofs.push(
        //   {
        //     chainId: BigInt(currentHop.chainId),
        //     blockId: BigInt(latestBlockNumber),
        //     rootHash: <- root of signalservice ->
        //     cacheOption: CacheOptions.CACHE_NOTHING,
        //     accountProof: [],
        //     storageProof: hopProof.storageProof[0].proof,
        //   }

        // Full proof
        hopProofs.push({
          chainId: BigInt(currentHop.chainId),
          blockId: BigInt(latestBlockNumber),
          rootHash: block.stateRoot,
          cacheOption: 0n, // Todo: could be configurable
          accountProof: hopProof.accountProof,
          storageProof: hopProof.storageProof[0].proof,
        });

        previousSrcChainId = BigInt(currentHop.chainId); // Update previousSrcChainId for the next iteration
      }

      return this.encodeHopProofs(hopProofs);
    } else {
      log('No hops configured, using default proof generation');
      const srcChainClient = getPublicClient(config, { chainId: Number(srcChainId) });
      if (!srcChainClient) throw new ClientError('Could not get public client');

      // Single hop proof

      // Get the signalServiceAddress for the source chain
      const srcSignalServiceAddress = routingContractsMap[Number(srcChainId)][Number(destChainId)].signalServiceAddress;

      // Get the latest synced block number from the relayer
      const blockInfo = await getFirstAvailableBlockInfo(Number(srcChainId));
      if (!blockInfo) throw new Error('Could not get latest block number from relayer');
      const { latestProcessedBlock } = blockInfo;

      // Get the block based on the blocknumber from the source chain
      const block = await srcChainClient.getBlock({ blockNumber });
      if (block.hash === null || block.number === null) {
        throw new BlockNotFoundError({ blockHash: block.hash, blockNumber: block.number });
      }
      if (latestProcessedBlock < block.number) {
        throw new BlockError('block is not synced yet');
      }

      // Build the signalSlot
      const key = await this.getSignalSlot(
        Number(srcChainId),
        routingContractsMap[Number(srcChainId)][Number(destChainId)].bridgeAddress,
        msgHash,
      );
      log('Storage key', key);

      // Call eth_getProof to get the proof
      const ethProof = await this.getProof({
        srcChainId: BigInt(srcChainId),
        blockNumber: BigInt(latestProcessedBlock),
        key,
        signalServiceAddress: srcSignalServiceAddress,
      });
      log('ethProof', ethProof);

      // Build the hopProof
      const hopProof: HopProof = {
        chainId: BigInt(destChainId),
        blockId: BigInt(blockNumber),
        rootHash: block.stateRoot,
        cacheOption: 0n, // Todo: could be configurable
        accountProof: ethProof.accountProof,
        storageProof: ethProof.storageProof[0].proof,
      };
      log('hopProof', hopProof);

      // Encode the hopProof
      const encodedHopProofs = this.encodeHopProofs([hopProof]);
      log('encodedHopProofs', encodedHopProofs);

      return encodedHopProofs;
    }
  }

  encodeHopProofs = (hopProofs: HopProof[]) => {
    const params: AbiParameter[] = [
      {
        type: 'tuple[]',
        name: 'hops',
        components: [
          {
            name: 'chainId',
            type: 'uint64',
          },
          {
            name: 'blockId',
            type: 'uint64',
          },
          {
            name: 'rootHash',
            type: 'bytes32',
          },
          {
            name: 'cacheOption',
            type: 'uint8',
          },
          {
            name: 'accountProof',
            type: 'bytes[]',
          },
          {
            name: 'storageProof',
            type: 'bytes[]',
          },
        ],
      },
    ];

    const values = hopProofs.map((hopProof) => [
      hopProof.chainId,
      hopProof.blockId,
      hopProof.rootHash,
      hopProof.cacheOption,
      hopProof.accountProof,
      hopProof.storageProof,
    ]);

    return encodeAbiParameters(params, [values]);
  };

  async getProof(args: GetProofArgs) {
    const { srcChainId, blockNumber: latestBlockNumber, key, signalServiceAddress: srcSignalServiceAddress } = args;

    let client;
    try {
      client = getPublicClient(config, { chainId: Number(srcChainId) });
    } catch (err) {
      throw new ClientError('Could not get public client');
    }
    if (!client) throw new ClientError('Could not get public client');

    const clientWithEthProofRequest = client as ClientWithEthGetProofRequest;

    log(`calling eth_getProof with ${srcSignalServiceAddress}, ${key}, ${numberToHex(latestBlockNumber as bigint)}`);

    const hopProof = await clientWithEthProofRequest.request({
      method: 'eth_getProof',
      params: [srcSignalServiceAddress, [key], numberToHex(latestBlockNumber as bigint)],
    });

    log('Proof from eth_getProof', hopProof);

    if (hopProof.storageProof[0].value === toHex(0)) {
      throw new ProofGenerationError('proof will not be valid, expected storageProof to not be 0 but was not');
    }
    return hopProof;
  }

  getLatestSrcBlockNumber = async (srcChainId: bigint, destChainId: bigint) => {
    const destSignalServiceAddress = routingContractsMap[Number(destChainId)][Number(srcChainId)].signalServiceAddress;

    const syncedChainData = await readContract(config, {
      address: destSignalServiceAddress,
      abi: signalServiceAbi,
      functionName: 'getSyncedChainData',
      args: [srcChainId, keccak256(toBytes('STATE_ROOT')), 0n],
      chainId: Number(destChainId),
    });
    log('syncedChainData', syncedChainData);

    const latestBlockNumber = syncedChainData[0];
    if (latestBlockNumber === null) {
      throw new BlockNotFoundError({
        blockNumber: latestBlockNumber,
      });
    }
    return latestBlockNumber;
  };
}
