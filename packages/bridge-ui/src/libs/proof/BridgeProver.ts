import { getPublicClient, readContract } from '@wagmi/core';
import {
  type Address,
  encodeAbiParameters,
  encodePacked,
  type Hash,
  type Hex,
  keccak256,
  numberToHex,
  toHex,
  toRlp,
} from 'viem';

import { crossChainSyncABI } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { MessageStatus } from '$libs/bridge';
import { InvalidProofError, PendingBlockError, WrongBridgeConfigError } from '$libs/error';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import type { ClientWithEthGetProofRequest, GenerateProofArgs, Hop } from './types';

const log = getLogger('proof:Prover');

export class BridgeProver {
  async getSignalSlot(chainId: number, contractAddress: Address, msgHash: Hex) {
    return keccak256(
      encodePacked(['string', 'uint64', 'address', 'bytes32'], ['SIGNAL', BigInt(chainId), contractAddress, msgHash]),
    );
  }

  protected async getBlockNumber(srcChainId: number, destChainId: number, crossChainSyncAddress: Address) {
    const syncedSnippet = await readContract(config, {
      address: crossChainSyncAddress,
      abi: crossChainSyncABI,
      functionName: 'getSyncedSnippet',
      args: [BigInt(0)],
      chainId: destChainId,
    });

    const client = getPublicClient(config, { chainId: srcChainId });
    if (!client) throw new Error('Could not get public client');

    const latestBlockHash = syncedSnippet['blockHash'];

    const block = await client.getBlock({ blockHash: latestBlockHash });
    if (block.hash === null || block.number === null) {
      throw new PendingBlockError('block is pending');
    }
    return block.number;
  }

  async encodedStorageProof(args: GenerateProofArgs) {
    const { msgHash, clientChainId, contractAddress, proofForAccountAddress, blockNumber } = args;
    const client = getPublicClient(config, { chainId: clientChainId });
    const key = await this.getSignalSlot(clientChainId, contractAddress, msgHash);
    log('Signal slot', key);

    // Unfortunately, since this method is stagnant, it hasn't been included into Viem lib
    // as supported methods. Still supported by Alchemy, Infura and others.
    // See https://eips.ethereum.org/EIPS/eip-1186
    // Following is a workaround to support this method.
    const clientWithEthProofRequest = client as ClientWithEthGetProofRequest;

    // RPC call to get the merkle proof what value is at key on the SignalService contract
    const proof = await clientWithEthProofRequest.request({
      method: 'eth_getProof',
      params: [
        // Address of the account to get the proof for
        proofForAccountAddress,

        // Array of storage-keys that should be proofed and included
        [key],

        numberToHex(blockNumber as bigint),
      ],
    });

    log('Proof from eth_getProof', proof);

    if (proof.storageProof[0].value !== toHex(true)) {
      throw new InvalidProofError('storage proof value is not 1');
    }

    // RLP encode the proof together for LibTrieProof to decode
    const rlpEncodedStorageProof = toRlp(proof.storageProof[0].proof);

    return { proof, rlpEncodedStorageProof };
  }

  async encodedSignalProof(msgHash: Hash, srcChainId: number, destChainId: number) {
    const hops = routingContractsMap[srcChainId][destChainId].hops;
    if (hops && hops.length > 0) {
      return await this._encodedSignalProofWithHops(msgHash, srcChainId, destChainId);
    } else {
      return await this._encodedSignalProofWithoutHops(msgHash, srcChainId, destChainId);
    }
  }

  // Reference: EncodedSignalProof in relayer/proof/encoded_signal_proof.go
  // protocol/contracts/signal/SignalService.sol
  async _encodedSignalProofWithoutHops(msgHash: Hash, srcChainId: number, destChainId: number) {
    const srcBridgeAddress = routingContractsMap[srcChainId][destChainId].bridgeAddress;
    const srcSignalServiceAddress = routingContractsMap[srcChainId][destChainId].signalServiceAddress;
    const destCrossChainSyncAddress = routingContractsMap[destChainId][srcChainId].crossChainSyncAddress;

    // Get the block from chain A based on the latest block hash
    // we get cross chain (Taiko contract on chain B)
    const blockNumber = await this.getBlockNumber(srcChainId, destChainId, destCrossChainSyncAddress);

    const { rlpEncodedStorageProof } = await this.encodedStorageProof({
      msgHash,
      clientChainId: srcChainId,
      contractAddress: srcBridgeAddress,
      proofForAccountAddress: srcSignalServiceAddress,
      blockNumber,
    });

    const signalProof = this._encodeAbiParameters(
      destCrossChainSyncAddress,
      BigInt(blockNumber),
      rlpEncodedStorageProof,
      [],
    );
    return signalProof;
  }

  async _encodedSignalProofWithHops(msgHash: Hash, srcChainId: number, destChainId: number) {
    const srcBridgeAddress = routingContractsMap[srcChainId][destChainId].bridgeAddress;
    const srcSignalServiceAddress = routingContractsMap[srcChainId][destChainId].signalServiceAddress;
    const destCrossChainSyncAddress = routingContractsMap[destChainId][srcChainId].crossChainSyncAddress;
    const hopParams = routingContractsMap[srcChainId][destChainId].hops;
    if (hopParams === undefined) throw new WrongBridgeConfigError('hops is undefined');

    let blockNumber = BigInt(0);
    // Initialize hopChainId with src chain
    let hopChainId: number = srcChainId;
    for (const hop of hopParams) {
      blockNumber = await this.getBlockNumber(hopChainId, hop.chainId, hop.crossChainSyncAddress);
      hopChainId = hop.chainId;
    }
    // Get the block number from last hop chain to dest chain
    blockNumber = await this.getBlockNumber(hopChainId, destChainId, destCrossChainSyncAddress);

    // Generate main storage proof with receipt.blockNumber
    const { proof, rlpEncodedStorageProof } = await this.encodedStorageProof({
      msgHash,
      clientChainId: srcChainId,
      contractAddress: srcBridgeAddress,
      proofForAccountAddress: srcSignalServiceAddress,
      blockNumber,
    });
    // The first signalRoot
    let signalRoot = proof.storageHash;
    log('successfully generated main storage proof', signalRoot);

    const hops: Hop[] = [];
    for (const hop of hopParams) {
      const { proof: hopProof, rlpEncodedStorageProof: hopRlpEncodedStorageProof } = await this.encodedStorageProof({
        msgHash: signalRoot,
        clientChainId: hop.chainId,
        contractAddress: hop.crossChainSyncAddress,
        proofForAccountAddress: hop.signalServiceAddress,
        blockNumber,
      });
      log('successfully generated hop storage proof', hopProof.storageHash);

      hops.push({
        signalRootRelay: hop.crossChainSyncAddress,
        signalRoot: signalRoot,
        storageProof: hopRlpEncodedStorageProof,
      });
      signalRoot = hopProof.storageHash;
    }

    const signalProof = this._encodeAbiParameters(
      destCrossChainSyncAddress,
      BigInt(blockNumber),
      rlpEncodedStorageProof,
      hops,
    );
    return signalProof;
  }

  async generateProofToRelease(msgHash: Hash, srcChainId: number, destChainId: number) {
    const srcBridgeAddress = routingContractsMap[srcChainId][destChainId].bridgeAddress;
    const destBridgeAddress = routingContractsMap[destChainId][srcChainId].bridgeAddress;
    const destCrossChainSyncAddress = routingContractsMap[destChainId][srcChainId].crossChainSyncAddress;

    const blockNumber = await this.getBlockNumber(srcChainId, destChainId, destCrossChainSyncAddress);

    const { proof } = await this.encodedStorageProof({
      msgHash,
      clientChainId: destChainId,
      contractAddress: srcBridgeAddress,
      proofForAccountAddress: destBridgeAddress,
      blockNumber,
    });

    // Value must be 0x3 => MessageStatus.FAILED
    if (proof.storageProof[0].value !== toHex(MessageStatus.FAILED)) {
      throw new InvalidProofError('storage proof value is not FAILED');
    }

    return this._encodedSignalProofWithoutHops(msgHash, destChainId, srcChainId);
  }

  _encodeAbiParameters(crossChainSync: Address, height: bigint, storageProof: Hex, hops: Hop[]) {
    return encodeAbiParameters(
      [
        {
          type: 'tuple',
          components: [
            { name: 'crossChainSync', type: 'address' },
            { name: 'height', type: 'uint64' },
            { name: 'storageProof', type: 'bytes' },
            {
              type: 'tuple[]',
              name: 'hops',
              components: [
                {
                  type: 'address',
                  name: 'signalRootRelay',
                },
                {
                  type: 'bytes32',
                  name: 'signalRoot',
                },
                {
                  type: 'bytes',
                  name: 'storageProof',
                },
              ],
            },
          ],
        },
      ],
      [
        {
          crossChainSync,
          height,
          storageProof,
          hops,
        },
      ],
    );
  }
}
