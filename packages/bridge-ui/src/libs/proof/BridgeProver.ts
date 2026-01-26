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
  toHex,
} from 'viem';

import { signalServiceAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
import { isL2Chain } from '$libs/chain';
import { BlockNotSyncedError, ClientError, ProofGenerationError } from '$libs/error';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { CacheOption, type ClientWithEthGetProofRequest, type GetProofArgs, type HopProof } from './types';

const log = getLogger('proof:Prover');

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
    const msgHashBigInt = BigInt(msgHash);
    const failedStatusBigInt = BigInt(MessageStatus.FAILED);
    const resultBigInt = msgHashBigInt ^ failedStatusBigInt;
    let resultHex = resultBigInt.toString(16).padStart(64, '0');
    resultHex = '0x' + resultHex;

    return resultHex as Hash;
  }

  /**
   * Gets the latest block number from chainA that has been synced to chainB.
   * - If chainB is L2 and chainA is L1: uses Anchor.getBlockState() on L2
   * - If chainB is L1 and chainA is L2: uses CheckpointSaved events on L1
   */
  async getLatestSyncedBlockNumber(chainA: bigint, chainB: bigint): Promise<bigint> {
    if (isL2Chain(Number(chainB))) {
      // chainB is L2, chainA is L1: query Anchor on L2
      const anchorAddress = routingContractsMap[Number(chainB)][Number(chainA)].anchorForkRouter;
      if (!anchorAddress) throw new BlockNotSyncedError('No anchor address configured');

      const blockState = await readContract(config, {
        address: anchorAddress,
        abi: anchorGetBlockStateAbi,
        functionName: 'getBlockState',
        chainId: Number(chainB),
      });

      return BigInt(blockState.anchorBlockNumber);
    } else {
      // chainB is L1, chainA is L2: query CheckpointSaved events on L1
      const signalServiceAddress = routingContractsMap[Number(chainB)][Number(chainA)].signalServiceAddress;

      const client = getPublicClient(config, { chainId: Number(chainB) });
      if (!client) throw new ClientError('Could not get public client');

      const currentBlock = await client.getBlockNumber();
      const fromBlock = currentBlock > 10000n ? currentBlock - 10000n : 0n;
      const logs = await client.getContractEvents({
        address: signalServiceAddress,
        abi: signalServiceAbi,
        eventName: 'CheckpointSaved',
        fromBlock,
        toBlock: currentBlock,
      });

      if (logs.length === 0) throw new BlockNotSyncedError('No checkpoints found');

      return BigInt(logs[logs.length - 1].args.blockNumber!);
    }
  }

  async getEncodedSignalProof({ bridgeTx }: { bridgeTx: BridgeTransaction }) {
    const { blockNumber, message, msgHash } = bridgeTx;

    log('msgHash', msgHash);
    if (!message) throw new ProofGenerationError('Message is not defined');
    if (!blockNumber) throw new ProofGenerationError('Block number is not defined');
    const { srcChainId, destChainId } = message;

    const srcChainClient = getPublicClient(config, { chainId: Number(srcChainId) });
    if (!srcChainClient) throw new ClientError('Could not get public client');

    const srcSignalServiceAddress = routingContractsMap[Number(srcChainId)][Number(destChainId)].signalServiceAddress;

    // Get latest src block synced on dest
    const latestSyncedBlock = await this.getLatestSyncedBlockNumber(srcChainId, destChainId);

    log('latestSyncedBlock', latestSyncedBlock);

    const synced = latestSyncedBlock >= hexToBigInt(blockNumber);
    log('synced', synced, latestSyncedBlock, hexToBigInt(blockNumber));
    if (!synced) {
      throw new BlockNotSyncedError('block is not synced yet');
    }

    // Verify the checkpoint exists on the destination chain BEFORE generating proof
    const destSignalServiceAddress = routingContractsMap[Number(destChainId)][Number(srcChainId)].signalServiceAddress;
    let checkpointStateRoot: Hex;
    try {
      const checkpoint = await readContract(config, {
        address: destSignalServiceAddress,
        abi: signalServiceAbi,
        functionName: 'getCheckpoint',
        args: [Number(latestSyncedBlock)],
        chainId: Number(destChainId),
      });
      checkpointStateRoot = checkpoint.stateRoot as Hex;
      log('Checkpoint verified on dest chain', { blockId: latestSyncedBlock, stateRoot: checkpointStateRoot });
    } catch (error) {
      log('Checkpoint NOT found on dest chain', { blockId: latestSyncedBlock, error });

      // Diagnostic: check if Anchor's checkpointStore matches our expected SignalService
      const anchorAddress = routingContractsMap[Number(destChainId)][Number(srcChainId)].anchorForkRouter;
      if (anchorAddress) {
        try {
          const actualCheckpointStore = await readContract(config, {
            address: anchorAddress,
            abi: anchorGetBlockStateAbi,
            functionName: 'checkpointStore',
            chainId: Number(destChainId),
          });
          log('Diagnostic: Anchor checkpointStore address', actualCheckpointStore);
          log('Diagnostic: Expected SignalService address', destSignalServiceAddress);
          if (actualCheckpointStore.toLowerCase() !== destSignalServiceAddress.toLowerCase()) {
            throw new ProofGenerationError(
              `Anchor's checkpointStore (${actualCheckpointStore}) does NOT match the configured SignalService ` +
                `(${destSignalServiceAddress}). Checkpoints are being saved to a different contract. ` +
                `Update signalServiceAddress in bridge config or fix the Anchor deployment.`,
            );
          }
        } catch (diagError) {
          if (diagError instanceof ProofGenerationError) throw diagError;
          log('Diagnostic: could not read checkpointStore from Anchor', diagError);
        }
      }

      throw new ProofGenerationError(
        `No checkpoint found on destination SignalService (${destSignalServiceAddress}) for block ${latestSyncedBlock}. ` +
          `The anchor may not have synced this block yet, or the SignalService fork may not be active.`,
      );
    }

    // Get the block from the source chain
    let block;
    try {
      block = await srcChainClient.getBlock({ blockNumber: latestSyncedBlock });
      if (!block || block.hash === null || block.number === null) {
        throw new BlockNotFoundError({ blockNumber: latestSyncedBlock });
      }
    } catch {
      throw new BlockNotFoundError({ blockNumber: latestSyncedBlock });
    }

    // Verify state root from L1 RPC matches checkpoint on L2
    if ((block.stateRoot as Hex) !== checkpointStateRoot) {
      log('STATE ROOT MISMATCH between L1 RPC and L2 checkpoint', {
        rpcStateRoot: block.stateRoot,
        checkpointStateRoot,
        blockNumber: latestSyncedBlock,
      });
      throw new ProofGenerationError(
        `State root mismatch: L1 RPC reports ${block.stateRoot} but L2 checkpoint has ${checkpointStateRoot} ` +
          `for block ${latestSyncedBlock}. This may indicate a chain reorg.`,
      );
    }

    // Build the signalSlot
    const key = await this.getSignalSlot(
      Number(srcChainId),
      routingContractsMap[Number(srcChainId)][Number(destChainId)].bridgeAddress,
      msgHash,
    );

    log('Storage key', key);

    // Call eth_getProof
    const ethProof = await this.getProof({
      chainId: BigInt(srcChainId),
      blockNumber: latestSyncedBlock,
      key,
      signalServiceAddress: srcSignalServiceAddress,
    });

    log('ethProof', ethProof);

    // Build single-hop proof
    // chainId is the hop's destination chain (where this proof will be verified)
    const hopProof: HopProof = {
      chainId: destChainId,
      blockId: BigInt(block.number),
      rootHash: block.stateRoot,
      cacheOption: CacheOption.CACHE_NOTHING, // Deprecated but required for ABI encoding
      accountProof: ethProof.accountProof,
      storageProof: ethProof.storageProof[0].proof,
    };
    log('hopProof', hopProof);

    const encodedProof = this.encodeHopProofs([hopProof]);
    log('encodedProof', encodedProof);

    // Pre-flight verification: check proof validity before returning (non-blocking)
    const srcBridgeAddress = routingContractsMap[Number(srcChainId)][Number(destChainId)].bridgeAddress;
    await this.verifyProofPreFlight({
      srcChainId: Number(srcChainId),
      destChainId: Number(destChainId),
      bridgeAddress: srcBridgeAddress,
      msgHash: msgHash as Hash,
      encodedProof,
      blockId: BigInt(block.number),
      rootHash: block.stateRoot as Hex,
    });

    return encodedProof;
  }

  async getEncodedSignalProofForRecall({ bridgeTx }: { bridgeTx: BridgeTransaction }) {
    const { blockNumber, message, msgHash } = bridgeTx;

    log('msgHash', msgHash);
    if (!message) throw new ProofGenerationError('Message is not defined');
    if (!blockNumber) throw new ProofGenerationError('Block number is not defined');
    const { srcChainId, destChainId } = message;

    const destChainClient = getPublicClient(config, { chainId: Number(destChainId) });
    if (!destChainClient) throw new ClientError('Could not get public client');

    const destSignalServiceAddress = routingContractsMap[Number(destChainId)][Number(srcChainId)].signalServiceAddress;

    // Get latest dest block synced on src
    const latestSyncedBlock = await this.getLatestSyncedBlockNumber(destChainId, srcChainId);

    log('latestSyncedBlock', latestSyncedBlock);

    const synced = latestSyncedBlock >= hexToBigInt(blockNumber);
    log('synced', synced, latestSyncedBlock, hexToBigInt(blockNumber));
    if (!synced) {
      throw new BlockNotSyncedError('block is not synced yet');
    }

    // Get the block from the destination chain
    let block;
    try {
      block = await destChainClient.getBlock({ blockNumber: latestSyncedBlock });
      if (!block || block.hash === null || block.number === null) {
        throw new BlockNotFoundError({ blockNumber: latestSyncedBlock });
      }
    } catch {
      throw new BlockNotFoundError({ blockNumber: latestSyncedBlock });
    }

    const signal = await this.getSignalForFailedMessage(msgHash);

    // Build the signalSlot
    const key = await this.getSignalSlot(
      Number(destChainId),
      routingContractsMap[Number(destChainId)][Number(srcChainId)].bridgeAddress,
      signal,
    );

    log('Storage key', key);

    // Call eth_getProof
    const ethProof = await this.getProof({
      chainId: BigInt(destChainId),
      blockNumber: latestSyncedBlock,
      key,
      signalServiceAddress: destSignalServiceAddress,
    });

    log('ethProof', ethProof, msgHash);

    // Build single-hop proof
    // For recall: signal is on destChain, verification happens on srcChain
    // chainId is the hop's destination chain (srcChain in this case)
    const hopProof: HopProof = {
      chainId: srcChainId,
      blockId: BigInt(block.number),
      rootHash: block.stateRoot,
      cacheOption: CacheOption.CACHE_NOTHING, // Deprecated but required for ABI encoding
      accountProof: ethProof.accountProof,
      storageProof: ethProof.storageProof[0].proof,
    };
    log('hopProof', hopProof);

    const encodedProof = this.encodeHopProofs([hopProof]);
    log('encodedProof', encodedProof);

    // Pre-flight verification for recall: proof is verified on srcChain
    const destBridgeAddress = routingContractsMap[Number(destChainId)][Number(srcChainId)].bridgeAddress;
    await this.verifyProofPreFlight({
      srcChainId: Number(destChainId), // signal is on destChain
      destChainId: Number(srcChainId), // verification happens on srcChain
      bridgeAddress: destBridgeAddress,
      msgHash: signal as Hash,
      encodedProof,
      blockId: BigInt(block.number),
      rootHash: block.stateRoot as Hex,
    });

    return encodedProof;
  }

  encodeHopProofs = (hopProofs: HopProof[]) => {
    // Must match ISignalService.HopProof struct exactly:
    // struct HopProof {
    //   uint64 chainId;
    //   uint64 blockId;
    //   bytes32 rootHash;
    //   CacheOption cacheOption; // enum, encoded as uint8
    //   bytes[] accountProof;
    //   bytes[] storageProof;
    // }
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
    const { chainId, blockNumber: latestBlockNumber, key, signalServiceAddress } = args;

    let client;
    try {
      client = getPublicClient(config, { chainId: Number(chainId) });
    } catch (err) {
      throw new ClientError('Could not get public client');
    }
    if (!client) throw new ClientError('Could not get public client');

    const clientWithEthProofRequest = client as ClientWithEthGetProofRequest;

    log(`calling eth_getProof with ${signalServiceAddress}, ${key}, ${numberToHex(latestBlockNumber as bigint)}`);

    const ethProof = await clientWithEthProofRequest.request({
      method: 'eth_getProof',
      params: [signalServiceAddress, [key], numberToHex(latestBlockNumber as bigint)],
    });

    log('Proof from eth_getProof', ethProof);

    if (ethProof.storageProof[0].value === toHex(0)) {
      throw new ProofGenerationError('proof will not be valid, expected storageProof to not be 0 but was not');
    }

    // Diagnostic: log actual storage value for debugging proof verification failures
    log('eth_getProof storage value:', ethProof.storageProof[0].value);
    log('eth_getProof storage key:', key);
    log('eth_getProof account address:', signalServiceAddress);

    return ethProof;
  }

  /**
   * Pre-flight verification: checks the proof against the destination chain's SignalService
   * before submitting the claim transaction. This helps identify the exact failure reason
   * since Bridge.sol masks all errors as B_SIGNAL_NOT_RECEIVED.
   */
  async verifyProofPreFlight({
    srcChainId,
    destChainId,
    bridgeAddress,
    msgHash,
    encodedProof,
    blockId,
    rootHash,
  }: {
    srcChainId: number;
    destChainId: number;
    bridgeAddress: Address;
    msgHash: Hash;
    encodedProof: Hex;
    blockId: bigint;
    rootHash: Hex;
  }) {
    const destSignalServiceAddress = routingContractsMap[Number(destChainId)][Number(srcChainId)].signalServiceAddress;

    // Step 1: Verify checkpoint exists on destination SignalService
    log('Pre-flight: checking checkpoint on dest SignalService', { blockId, destSignalServiceAddress, destChainId });
    try {
      const checkpoint = await readContract(config, {
        address: destSignalServiceAddress,
        abi: signalServiceAbi,
        functionName: 'getCheckpoint',
        args: [Number(blockId)],
        chainId: destChainId,
      });

      log('Pre-flight: checkpoint found', checkpoint);

      // Step 2: Compare state roots
      if (checkpoint.stateRoot !== rootHash) {
        log('Pre-flight: STATE ROOT MISMATCH!', {
          checkpointStateRoot: checkpoint.stateRoot,
          proofRootHash: rootHash,
          blockId,
        });
        throw new ProofGenerationError(
          `State root mismatch: checkpoint has ${checkpoint.stateRoot} but proof uses ${rootHash} for blockId ${blockId}`,
        );
      }
      log('Pre-flight: state roots match');
    } catch (error) {
      if (error instanceof ProofGenerationError) throw error;
      log('Pre-flight: CHECKPOINT NOT FOUND', { blockId, error });
      throw new ProofGenerationError(
        `Checkpoint not found on dest SignalService for blockId ${blockId}. The L1 block may not have been anchored yet.`,
      );
    }

    // Step 3: Call verifySignalReceived (view) on destination SignalService
    // This is NON-BLOCKING: failures are logged as warnings but don't prevent the claim attempt
    log('Pre-flight: calling verifySignalReceived', {
      srcChainId,
      bridgeAddress,
      msgHash,
      destSignalServiceAddress,
    });
    try {
      const destClient = getPublicClient(config, { chainId: destChainId });
      if (!destClient) throw new ClientError('Could not get dest chain public client');

      const callData = encodeFunctionData({
        abi: signalServiceAbi,
        functionName: 'verifySignalReceived',
        args: [BigInt(srcChainId), bridgeAddress, msgHash, encodedProof],
      });

      await destClient.call({
        to: destSignalServiceAddress,
        data: callData,
      });
      log('Pre-flight: verifySignalReceived succeeded - proof is valid');
    } catch (error: unknown) {
      // Non-blocking: log warning but don't prevent the claim attempt
      const errorMessage = error instanceof Error ? error.message : String(error);
      log('Pre-flight: verifySignalReceived FAILED (non-blocking)', {
        error: errorMessage,
        srcChainId,
        bridgeAddress,
        msgHash,
        blockId: blockId.toString(),
      });
    }
  }
}
