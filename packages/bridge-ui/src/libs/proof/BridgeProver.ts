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
import { BlockError, ClientError, ProofGenerationError } from '$libs/error';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { CacheOptions, type ClientWithEthGetProofRequest, type GetProofArgs, type HopProof } from './types';

const log = getLogger('proof:Prover');

export class BridgeProver {
  async getSignalSlot(chainId: number, contractAddress: Address, msgHash: Hex) {
    return keccak256(
      encodePacked(['string', 'uint64', 'address', 'bytes32'], ['SIGNAL', BigInt(chainId), contractAddress, msgHash]),
    );
  }

  protected async getBlockNumber(srcChainId: number, destChainId: number, crossChainSyncAddress: Address) {
    const syncedChainData = await readContract(config, {
      address: crossChainSyncAddress,
      abi: signalServiceAbi,
      functionName: 'getSyncedChainData',
      args: [BigInt(srcChainId), keccak256(toBytes('STATE_ROOT')), BigInt(0)],
      chainId: destChainId,
    });

    const blockNumber = syncedChainData[0];
    if (blockNumber === null) {
      throw new BlockNotFoundError({
        blockNumber: blockNumber,
      });
    }

    return blockNumber;
  }

  async getEncodedSignalProof(args: GetProofArgs) {
    const { bridgeTx } = args;
    const { blockNumber, message, msgHash } = bridgeTx;
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

        const syncedChainData = await readContract(config, {
          address: currentSignalServiceAddress,
          abi: signalServiceAbi,
          functionName: 'getSyncedChainData',
          args: [BigInt(destChainId), keccak256(toBytes('STATE_ROOT')), 0n],
          chainId: Number(previousSrcChainId),
        });

        const latestBlockNumber = syncedChainData[0];

        const hopClient = getPublicClient(config, { chainId: Number(currentHop.chainId) });
        if (!hopClient) throw new Error('Could not get public client');

        const block = await hopClient.getBlock({ blockNumber: blockNumber });
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
          cacheOption: CacheOptions.CACHE_NOTHING, // Todo: could be configurable
          accountProof: hopProof.accountProof,
          storageProof: hopProof.storageProof[0].proof,
        });

        previousSrcChainId = BigInt(currentHop.chainId); // Update previousSrcChainId for the next iteration
      }

      return this._encodeAbiParameters(hopProofs);
    } else {
      const destSignalServiceAddress =
        routingContractsMap[Number(destChainId)][Number(srcChainId)].signalServiceAddress;

      const syncedChainData = await readContract(config, {
        address: destSignalServiceAddress,
        abi: signalServiceAbi,
        functionName: 'getSyncedChainData',
        args: [destChainId, keccak256(toBytes('STATE_ROOT')), 0n],
        chainId: Number(srcChainId),
      });

      const latestBlockNumber = syncedChainData[0];
      const hopClient = getPublicClient(config, { chainId: Number(srcChainId) });
      if (!hopClient) throw new ClientError('Could not get public client');

      const block = await hopClient.getBlock({ blockNumber: blockNumber });
      if (block.hash === null || block.number === null) {
        throw new BlockNotFoundError({ blockHash: block.hash, blockNumber: block.number });
      }
      if (latestBlockNumber < block.number) {
        //TODO handle this earlier somehow?
        throw new BlockError('block is not synced yet');
      }

      const clientWithEthProofRequest = hopClient as ClientWithEthGetProofRequest;
      const hopProof = await clientWithEthProofRequest.request({
        method: 'eth_getProof',
        params: [destSignalServiceAddress, [key], numberToHex(latestBlockNumber as bigint)],
      });
      log('Proof from eth_getProof', hopProof);

      if (hopProof.storageProof[0].value === toHex(0)) {
        throw new Error('proof will not be valid, expected storageProof to not be 0 but was not');
      }

      const proof = {
        chainId: BigInt(srcChainId),
        blockId: BigInt(latestBlockNumber),
        rootHash: block.stateRoot,
        cacheOption: CacheOptions.CACHE_NOTHING, // Todo: could be configurable
        accountProof: hopProof.accountProof,
        storageProof: hopProof.storageProof[0].proof,
      };
      return this._encodeAbiParameters([proof]);
    }
  }

  _encodeAbiParameters(hops: HopProof[]) {
    return encodeAbiParameters(
      [
        {
          type: 'tuple',
          components: [
            {
              type: 'tuple[]',
              name: 'hops',
              components: [
                {
                  type: 'uint64',
                  name: 'chainId',
                },
                {
                  type: 'uint64',
                  name: 'blockId',
                },
                {
                  type: 'bytes32',
                  name: 'rootHash',
                },
                {
                  type: 'enum',
                  name: 'cacheOption',
                },
                {
                  type: 'bytes[]',
                  name: 'accountProof',
                },
                {
                  type: 'bytes[]',
                  name: 'storageProof',
                },
              ],
            },
          ],
        },
      ],
      [
        {
          hops,
        },
      ],
    );
  }
}
