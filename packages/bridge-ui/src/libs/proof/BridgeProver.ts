import { getPublicClient, readContract } from '@wagmi/core';
import {
  type Address,
  BlockNotFoundError,
  encodeAbiParameters,
  encodeFunctionData,
  encodePacked,
  type Hash,
  type Hex,
  hexToBigInt,
  keccak256,
  numberToHex,
  toBytes,
  toHex,
} from 'viem';

import { pacayaSignalServiceAbi, signalServiceAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
import { isL2Chain } from '$libs/chain';
import { BlockNotSyncedError, ClientError, ProofGenerationError } from '$libs/error';
import { getProtocolVersion, ProtocolVersion } from '$libs/protocol/protocolVersion';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { CacheOption, type ClientWithEthGetProofRequest, type GetProofArgs, type HopProof } from './types';

const log = getLogger('proof:Prover');

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
  {
    type: 'function',
    name: 'checkpointStore',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view',
  },
] as const;

export class BridgeProver {
  async getSignalSlot(chainId: number, contractAddress: Address, msgHash: Hex) {
    return keccak256(
      encodePacked(['string', 'uint64', 'address', 'bytes32'], ['SIGNAL', BigInt(chainId), contractAddress, msgHash]),
    );
  }

  async getSignalForFailedMessage(msgHash: Hash): Promise<Hash> {
    const resultBigInt = BigInt(msgHash) ^ BigInt(MessageStatus.FAILED);
    return ('0x' + resultBigInt.toString(16).padStart(64, '0')) as Hash;
  }

  /**
   * Gets the latest block number from srcChain that has been synced to destChain.
   */
  async getLatestSyncedBlockNumber(srcChainId: bigint, destChainId: bigint): Promise<bigint> {
    const protocol = await getProtocolVersion(Number(srcChainId), Number(destChainId));

    if (protocol === ProtocolVersion.PACAYA) {
      return this.getLatestSyncedBlockPacaya(srcChainId, destChainId);
    }
    return this.getLatestSyncedBlockShasta(srcChainId, destChainId);
  }

  private async getLatestSyncedBlockPacaya(srcChainId: bigint, destChainId: bigint): Promise<bigint> {
    const destSignalService = routingContractsMap[Number(destChainId)][Number(srcChainId)].signalServiceAddress;
    const result = await readContract(config, {
      address: destSignalService,
      abi: pacayaSignalServiceAbi,
      functionName: 'getSyncedChainData',
      args: [srcChainId, keccak256(toBytes('STATE_ROOT')), 0n],
      chainId: Number(destChainId),
    });
    return result[0];
  }

  private async getLatestSyncedBlockShasta(srcChainId: bigint, destChainId: bigint): Promise<bigint> {
    if (isL2Chain(Number(destChainId))) {
      // L1→L2: query Anchor on L2
      const anchorAddress = routingContractsMap[Number(destChainId)][Number(srcChainId)].anchorForkRouter;
      if (!anchorAddress) throw new ClientError('No anchor address configured for this route');

      const blockState = await readContract(config, {
        address: anchorAddress,
        abi: anchorGetBlockStateAbi,
        functionName: 'getBlockState',
        chainId: Number(destChainId),
      });
      return BigInt(blockState.anchorBlockNumber);
    }

    // L2→L1: query CheckpointSaved events on L1
    const signalService = routingContractsMap[Number(destChainId)][Number(srcChainId)].signalServiceAddress;
    const client = getPublicClient(config, { chainId: Number(destChainId) });
    if (!client) throw new ClientError('Could not get public client');

    const currentBlock = await client.getBlockNumber();
    const fromBlock = currentBlock > MAX_CHECKPOINT_SEARCH_BLOCKS ? currentBlock - MAX_CHECKPOINT_SEARCH_BLOCKS : 0n;
    const logs = await client.getContractEvents({
      address: signalService,
      abi: signalServiceAbi,
      eventName: 'CheckpointSaved',
      fromBlock,
      toBlock: currentBlock,
    });

    if (logs.length === 0) throw new BlockNotSyncedError('No checkpoints found');
    return BigInt(logs[logs.length - 1].args.blockNumber!);
  }

  async getEncodedSignalProof({ bridgeTx }: { bridgeTx: BridgeTransaction }) {
    const { blockNumber, message, msgHash } = bridgeTx;
    if (!message) throw new ProofGenerationError('Message is not defined');
    if (!blockNumber) throw new ProofGenerationError('Block number is not defined');

    const { srcChainId, destChainId } = message;
    const protocol = await getProtocolVersion(Number(srcChainId), Number(destChainId));
    const configuredHops = routingContractsMap[Number(srcChainId)][Number(destChainId)].hops;

    // Multi-hop is only supported in Pacaya
    if (configuredHops?.length) {
      if (protocol !== ProtocolVersion.PACAYA) {
        throw new ProofGenerationError('Multi-hop routing is only supported on Pacaya protocol');
      }
      return this.generateMultiHopProof(bridgeTx, configuredHops);
    }

    // Single-hop proof (both protocols)
    const latestSyncedBlock = await this.getLatestSyncedBlockNumber(srcChainId, destChainId);
    log('latestSyncedBlock', latestSyncedBlock);

    if (latestSyncedBlock < hexToBigInt(blockNumber)) {
      throw new BlockNotSyncedError('block is not synced yet');
    }

    // Shasta: verify checkpoint exists before generating proof
    if (protocol === ProtocolVersion.SHASTA) {
      await this.verifyCheckpoint(Number(srcChainId), Number(destChainId), latestSyncedBlock);
    }

    return this.generateSingleHopProof({
      srcChainId: Number(srcChainId),
      destChainId: Number(destChainId),
      latestSyncedBlock,
      msgHash,
      verifyPreFlight: protocol === ProtocolVersion.SHASTA,
    });
  }

  private async generateMultiHopProof(
    bridgeTx: BridgeTransaction,
    hops: { chainId: number; signalServiceAddress: Address }[],
  ): Promise<Hex> {
    const { message, msgHash } = bridgeTx;
    if (!message) throw new ProofGenerationError('Message is not defined');

    const { srcChainId, destChainId } = message;
    const key = await this.getSignalSlot(
      Number(srcChainId),
      routingContractsMap[Number(srcChainId)][Number(destChainId)].bridgeAddress,
      msgHash,
    );

    const hopProofs: HopProof[] = [];
    let previousChainId = srcChainId;

    for (let i = 0; i < hops.length; i++) {
      const hop = hops[i];
      const signalServiceAddress =
        routingContractsMap[Number(previousChainId)]?.[Number(hop.chainId)]?.signalServiceAddress ??
        hop.signalServiceAddress;
      if (!signalServiceAddress) {
        throw new ClientError('No signal service address configured for hop');
      }

      const blockNumber = await this.getLatestSyncedBlockPacaya(previousChainId, BigInt(hop.chainId));
      const sourceClient = getPublicClient(config, { chainId: Number(previousChainId) });
      if (!sourceClient) throw new ClientError('Could not get public client for hop source chain');

      const block = await sourceClient.getBlock({ blockNumber });
      if (!block?.hash || block.number === null) {
        throw new BlockNotFoundError({ blockNumber });
      }

      const proof = await (sourceClient as ClientWithEthGetProofRequest).request({
        method: 'eth_getProof',
        params: [signalServiceAddress, [key], numberToHex(blockNumber)],
      });

      hopProofs.push({
        chainId: BigInt(hop.chainId),
        blockId: block.number,
        rootHash: block.stateRoot,
        cacheOption: CacheOption.CACHE_NOTHING,
        accountProof: proof.accountProof,
        storageProof: proof.storageProof[0].proof,
      });

      previousChainId = BigInt(hop.chainId);
    }

    return this.encodeHopProofs(hopProofs);
  }

  private async generateSingleHopProof({
    srcChainId,
    destChainId,
    latestSyncedBlock,
    msgHash,
    verifyPreFlight = false,
  }: {
    srcChainId: number;
    destChainId: number;
    latestSyncedBlock: bigint;
    msgHash: Hash;
    verifyPreFlight?: boolean;
  }): Promise<Hex> {
    const srcClient = getPublicClient(config, { chainId: srcChainId });
    if (!srcClient) throw new ClientError('Could not get public client');

    const block = await srcClient.getBlock({ blockNumber: latestSyncedBlock });
    if (!block?.hash || block.number === null) {
      throw new BlockNotFoundError({ blockNumber: latestSyncedBlock });
    }

    const key = await this.getSignalSlot(
      srcChainId,
      routingContractsMap[srcChainId][destChainId].bridgeAddress,
      msgHash,
    );

    const ethProof = await this.getProof({
      chainId: BigInt(srcChainId),
      blockNumber: latestSyncedBlock,
      key,
      signalServiceAddress: routingContractsMap[srcChainId][destChainId].signalServiceAddress,
    });

    const hopProof: HopProof = {
      chainId: BigInt(destChainId),
      blockId: block.number,
      rootHash: block.stateRoot,
      cacheOption: CacheOption.CACHE_NOTHING,
      accountProof: ethProof.accountProof,
      storageProof: ethProof.storageProof[0].proof,
    };

    const encodedProof = this.encodeHopProofs([hopProof]);

    if (verifyPreFlight) {
      await this.verifyProofPreFlight({
        srcChainId,
        destChainId,
        msgHash,
        encodedProof,
        blockId: block.number,
        rootHash: block.stateRoot as Hex,
      });
    }

    return encodedProof;
  }

  private async verifyCheckpoint(srcChainId: number, destChainId: number, blockNumber: bigint): Promise<void> {
    const destSignalService = routingContractsMap[destChainId][srcChainId].signalServiceAddress;

    try {
      await readContract(config, {
        address: destSignalService,
        abi: signalServiceAbi,
        functionName: 'getCheckpoint',
        args: [Number(blockNumber)],
        chainId: destChainId,
      });
    } catch (error) {
      log('Checkpoint NOT found', { blockNumber, error });

      // Diagnostic: check if Anchor's checkpointStore matches SignalService
      const anchorAddress = routingContractsMap[destChainId][srcChainId].anchorForkRouter;
      if (anchorAddress) {
        try {
          const checkpointStore = await readContract(config, {
            address: anchorAddress,
            abi: anchorGetBlockStateAbi,
            functionName: 'checkpointStore',
            chainId: destChainId,
          });
          if (checkpointStore.toLowerCase() !== destSignalService.toLowerCase()) {
            throw new ProofGenerationError(
              `Anchor's checkpointStore (${checkpointStore}) does NOT match SignalService (${destSignalService})`,
            );
          }
        } catch (e) {
          if (e instanceof ProofGenerationError) throw e;
        }
      }

      throw new ProofGenerationError(
        `No checkpoint found on SignalService (${destSignalService}) for block ${blockNumber}`,
      );
    }
  }

  async getEncodedSignalProofForRecall({ bridgeTx }: { bridgeTx: BridgeTransaction }) {
    const { blockNumber, message, msgHash } = bridgeTx;
    if (!message) throw new ProofGenerationError('Message is not defined');
    if (!blockNumber) throw new ProofGenerationError('Block number is not defined');

    const { srcChainId, destChainId } = message;
    const protocol = await getProtocolVersion(Number(destChainId), Number(srcChainId));
    const latestSyncedBlock = await this.getLatestSyncedBlockNumber(destChainId, srcChainId);

    if (latestSyncedBlock < hexToBigInt(blockNumber)) {
      throw new BlockNotSyncedError('block is not synced yet');
    }

    // Shasta: verify checkpoint exists before generating proof
    if (protocol === ProtocolVersion.SHASTA) {
      await this.verifyCheckpoint(Number(destChainId), Number(srcChainId), latestSyncedBlock);
    }

    const destClient = getPublicClient(config, { chainId: Number(destChainId) });
    if (!destClient) throw new ClientError('Could not get public client');

    const block = await destClient.getBlock({ blockNumber: latestSyncedBlock });
    if (!block?.hash || block.number === null) {
      throw new BlockNotFoundError({ blockNumber: latestSyncedBlock });
    }

    const signal = await this.getSignalForFailedMessage(msgHash);
    const key = await this.getSignalSlot(
      Number(destChainId),
      routingContractsMap[Number(destChainId)][Number(srcChainId)].bridgeAddress,
      signal,
    );

    const ethProof = await this.getProof({
      chainId: destChainId,
      blockNumber: latestSyncedBlock,
      key,
      signalServiceAddress: routingContractsMap[Number(destChainId)][Number(srcChainId)].signalServiceAddress,
    });

    const hopProof: HopProof = {
      chainId: srcChainId,
      blockId: block.number,
      rootHash: block.stateRoot,
      cacheOption: CacheOption.CACHE_NOTHING,
      accountProof: ethProof.accountProof,
      storageProof: ethProof.storageProof[0].proof,
    };

    return this.encodeHopProofs([hopProof]);
  }

  encodeHopProofs = (hopProofs: HopProof[]) => {
    const params = [
      {
        type: 'tuple[]',
        name: 'hops',
        components: [
          { name: 'chainId', type: 'uint64' },
          { name: 'blockId', type: 'uint64' },
          { name: 'rootHash', type: 'bytes32' },
          { name: 'cacheOption', type: 'uint8' },
          { name: 'accountProof', type: 'bytes[]' },
          { name: 'storageProof', type: 'bytes[]' },
        ],
      },
    ];

    const values = hopProofs.map((hp) => [
      hp.chainId,
      hp.blockId,
      hp.rootHash,
      hp.cacheOption,
      hp.accountProof,
      hp.storageProof,
    ]);

    return encodeAbiParameters(params, [values]);
  };

  async getProof(args: GetProofArgs) {
    const { chainId, blockNumber, key, signalServiceAddress } = args;

    const client = getPublicClient(config, { chainId: Number(chainId) });
    if (!client) throw new ClientError('Could not get public client');

    const ethProof = await (client as ClientWithEthGetProofRequest).request({
      method: 'eth_getProof',
      params: [signalServiceAddress, [key], numberToHex(blockNumber)],
    });

    if (ethProof.storageProof[0].value === toHex(0)) {
      throw new ProofGenerationError('proof will not be valid, expected storageProof to not be 0');
    }

    return ethProof;
  }

  async verifyProofPreFlight({
    srcChainId,
    destChainId,
    msgHash,
    encodedProof,
    blockId,
    rootHash,
  }: {
    srcChainId: number;
    destChainId: number;
    msgHash: Hash;
    encodedProof: Hex;
    blockId: bigint;
    rootHash: Hex;
  }) {
    const destSignalService = routingContractsMap[destChainId][srcChainId].signalServiceAddress;
    const bridgeAddress = routingContractsMap[srcChainId][destChainId].bridgeAddress;

    try {
      const checkpoint = await readContract(config, {
        address: destSignalService,
        abi: signalServiceAbi,
        functionName: 'getCheckpoint',
        args: [Number(blockId)],
        chainId: destChainId,
      });

      if (checkpoint.stateRoot !== rootHash) {
        throw new ProofGenerationError(
          `State root mismatch: checkpoint has ${checkpoint.stateRoot} but proof uses ${rootHash}`,
        );
      }
    } catch (error) {
      if (error instanceof ProofGenerationError) throw error;
      throw new ProofGenerationError(`Checkpoint not found for blockId ${blockId}`);
    }

    // Non-blocking verification call
    try {
      const client = getPublicClient(config, { chainId: destChainId });
      if (!client) return;

      await client.call({
        to: destSignalService,
        data: encodeFunctionData({
          abi: signalServiceAbi,
          functionName: 'verifySignalReceived',
          args: [BigInt(srcChainId), bridgeAddress, msgHash, encodedProof],
        }),
      });
      log('Pre-flight: verifySignalReceived succeeded');
    } catch (error) {
      log('Pre-flight: verifySignalReceived failed (non-blocking)', error);
    }
  }
}
