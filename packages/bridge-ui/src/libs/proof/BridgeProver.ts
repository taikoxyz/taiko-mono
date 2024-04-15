import { getPublicClient, readContract } from '@wagmi/core';
import {
  type Address,
  BlockNotFoundError,
  encodeAbiParameters,
  encodePacked,
  type Hash,
  type Hex,
  hexToBigInt,
  keccak256,
  numberToHex,
  toBytes,
  toHex,
} from 'viem';

import { signalServiceAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
import { BlockNotSyncedError, ClientError, ProofGenerationError } from '$libs/error';
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

  async getSignalForFailedMessage(msgHash: Hash): Promise<Hash> {
    const msgHashBigInt = BigInt(msgHash);
    const failedStatusBigInt = BigInt(MessageStatus.FAILED);
    const resultBigInt = msgHashBigInt ^ failedStatusBigInt;
    let resultHex = resultBigInt.toString(16).padStart(64, '0');
    resultHex = '0x' + resultHex;

    return resultHex as Hash;
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
      // Single hop proof
      log('No hops configured, using default proof generation');
      const srcChainClient = getPublicClient(config, { chainId: Number(srcChainId) });
      if (!srcChainClient) throw new ClientError('Could not get public client');

      // Get the signalServiceAddress for the source chain
      const srcSignalServiceAddress = routingContractsMap[Number(srcChainId)][Number(destChainId)].signalServiceAddress;
      const destSignalServiceAddress =
        routingContractsMap[Number(destChainId)][Number(srcChainId)].signalServiceAddress;

      const syncedChainData = await readContract(config, {
        address: destSignalServiceAddress,
        abi: signalServiceAbi,
        functionName: 'getSyncedChainData',
        args: [srcChainId, keccak256(toBytes('STATE_ROOT')), 0n],
        chainId: Number(destChainId),
      });

      log('syncedChainData', syncedChainData);

      const latestSyncedblock = syncedChainData[0];

      const synced = latestSyncedblock >= hexToBigInt(blockNumber);
      log('synced', synced, latestSyncedblock, hexToBigInt(blockNumber));
      if (!synced) {
        throw new BlockNotSyncedError('block is not synced yet');
      }

      // Get the block based on the blocknumber from the source chain
      let block;
      try {
        block = await srcChainClient.getBlock({ blockNumber: latestSyncedblock });
        if (!block || block.hash === null || block.number === null) {
          throw new BlockNotFoundError({ blockNumber: latestSyncedblock });
        }
      } catch {
        throw new BlockNotFoundError({ blockNumber: latestSyncedblock });
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
        blockNumber: BigInt(latestSyncedblock),
        key,
        signalServiceAddress: srcSignalServiceAddress,
      });

      log('ethProof', ethProof);

      // Build the hopProof
      const hopProof: HopProof = {
        chainId: BigInt(destChainId),
        blockId: BigInt(block.number),
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

  async getEncodedSignalProofForRecall({ bridgeTx }: { bridgeTx: BridgeTransaction }) {
    const { message, msgHash } = bridgeTx;

    log('msgHash', msgHash);
    if (!message) throw new ProofGenerationError('Message is not defined');
    const { srcChainId, destChainId } = message;

    let previousDestChainId = destChainId;
    const key = await this.getSignalSlot(
      Number(destChainId),
      routingContractsMap[Number(destChainId)][Number(srcChainId)].bridgeAddress,
      msgHash,
    );
    const configuredHops = routingContractsMap[Number(destChainId)][Number(srcChainId)].hops;

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

        const latestBlockNumber = await this.getLatestSrcBlockNumber(previousDestChainId, srcChainId);

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

        previousDestChainId = BigInt(currentHop.chainId); // Update previousSrcChainId for the next iteration
      }

      return this.encodeHopProofs(hopProofs);
    } else {
      // Single hop proof
      log('No hops configured, using default proof generation');
      const destChainClient = getPublicClient(config, { chainId: Number(destChainId) });
      if (!destChainClient) throw new ClientError('Could not get public client');

      // Get the signalServiceAddress for the source chain
      const destSignalServiceAddress =
        routingContractsMap[Number(destChainId)][Number(srcChainId)].signalServiceAddress;

      const block = await destChainClient.getBlock({ blockTag: 'latest' });

      const signal = await this.getSignalForFailedMessage(msgHash);

      // Build the signalSlot
      const key = await this.getSignalSlot(
        Number(destChainId),
        routingContractsMap[Number(destChainId)][Number(srcChainId)].bridgeAddress,
        signal,
      );

      log('Storage key', key);

      // Call eth_getProof to get the proof
      const ethProof = await this.getProof({
        srcChainId: BigInt(destChainId),
        blockNumber: block.number,
        key,
        signalServiceAddress: destSignalServiceAddress,
      });

      log('ethProof', ethProof, msgHash);

      // Build the hopProof
      const hopProof: HopProof = {
        chainId: BigInt(destChainId),
        blockId: BigInt(block.number),
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

    const ethProof = await clientWithEthProofRequest.request({
      method: 'eth_getProof',
      params: [srcSignalServiceAddress, [key], numberToHex(latestBlockNumber as bigint)],
    });

    log('Proof from eth_getProof', ethProof);

    // check if signal is failed:

    if (ethProof.storageProof[0].value === toHex(0)) {
      throw new ProofGenerationError('proof will not be valid, expected storageProof to not be 0 but was not');
    }
    return ethProof;
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
