import { getContract, type GetContractResult, type PublicClient } from '@wagmi/core';
import {
  type Address,
  encodeAbiParameters,
  encodePacked,
  type Hex,
  keccak256,
  toHex,
  toRlp,
  type TransactionReceipt,
} from 'viem';
import type { Hash } from '@wagmi/core';

import { crossChainSyncABI } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { MessageStatus } from '$libs/bridge';
import { InvalidProofError, PendingBlockError } from '$libs/error';
import { getLogger } from '$libs/util/logger';
import { publicClient } from '$libs/wagmi';

import type { ClientWithEthGetProofRequest, GenerateProofArgs, Hop } from './types';

const log = getLogger('proof:Prover');

export class BridgeProver {
  async getSignalSlot(chainId: number, contractAddress: Address, msgHash: Hex) {
    return keccak256(
      encodePacked(['string', 'uint64', 'address', 'bytes32'], ['SIGNAL', BigInt(chainId), contractAddress, msgHash]),
    );
  }

  protected async getBlockNumber(srcChainId: number, destChainId: number, crossChainSyncAddress: Address) {
    const crossChainSyncContract = getContract({
      chainId: destChainId,
      address: crossChainSyncAddress,
      abi: crossChainSyncABI,
    });
    const client = publicClient({ chainId: srcChainId });
    const syncedSnippet = await crossChainSyncContract.read.getSyncedSnippet([BigInt(0)]);
    const latestBlockHash = syncedSnippet['blockHash'];
    const block = await client.getBlock({ blockHash: latestBlockHash });
    if (block.hash === null || block.number === null) {
      throw new PendingBlockError('block is pending');
    }
    return block.number;
  }

  protected async getBlockFromGetSyncedSnippet(
    client: PublicClient,
    crossChainSyncContract: GetContractResult<typeof crossChainSyncABI>,
    blockNumber: number,
  ) {
    const syncedSnippet = await crossChainSyncContract.read.getSyncedSnippet([BigInt(blockNumber)]);
    const latestBlockHash = syncedSnippet['blockHash'];
    const block = await client.getBlock({ blockHash: latestBlockHash });
    return { block, syncedSnippet };
  }

  async encodedStorageProof(args: GenerateProofArgs) {
    let { msgHash, clientChainId, contractAddress, proofForAccountAddress, blockNumber } = args;
    const client = publicClient({ chainId: clientChainId });
    let key = await this.getSignalSlot(clientChainId, contractAddress, msgHash);
    log('Signal slot', key);

    // Unfortunately, since this method is stagnant, it hasn't been included into Viem lib
    // as supported methods. Still stupported  by Alchmey, Infura and others.
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

        toHex(blockNumber),
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

  async encodeSignalProof(msgHash: Hash,
    receipt: TransactionReceipt,
    srcChainId: number,
    destChainId: number,
  ) {
    const hops = routingContractsMap[srcChainId][destChainId].hops;
    if (hops && hops.length > 0) {
      return await this._encodedSignalProofWithHops(msgHash, receipt, srcChainId, destChainId);
    } else {
      return await this._encodedSignalProofWithoutHops(msgHash, srcChainId, destChainId);
    }
  }

  // Reference: EncodedSignalProof in relayer/proof/encoded_signal_proof.go
  // protocol/contracts/signal/SignalService.sol
  async _encodedSignalProofWithoutHops(msgHash: Hash, srcChainId: number, destChainId: number) {
    const srcBridgeAddress = routingContractsMap[srcChainId][destChainId].bridgeAddress;
    const srcSignalServiceAddress = routingContractsMap[srcChainId][destChainId].signalServiceAddress;
    const destCrossChainSyncAddress = routingContractsMap[destChainId][srcChainId].taikoAddress;

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

  async _encodedSignalProofWithHops(
    msgHash: Hash,
    receipt: TransactionReceipt,
    srcChainId: number,
    destChainId: number,
  ) {
    const srcBridgeAddress = routingContractsMap[srcChainId][destChainId].bridgeAddress;
    const srcSignalServiceAddress = routingContractsMap[srcChainId][destChainId].signalServiceAddress;
    const destCrossChainSyncAddress = routingContractsMap[destChainId][srcChainId].taikoAddress;
    const hopParams = routingContractsMap[srcChainId][destChainId].hops;

    let blockNumber: number = 0;
    // Initialize hopChainId with src chain
    let hopChainId: number = srcChainId;
    for (var hop of hopParams) {
      blockNumber = await this.getBlockNumber(hopChainId, hop.chainId, hop.taikoAddress);
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
      blockNumber: receipt.blockNumber,
    });
    // The first signalRoot
    let signalRoot = proof.storageHash;
    log('successfully generated main storage proof', signalRoot);

    let hops: Hop[] = [];
    for (var hop of hopParams) {
      const { proof: hopProof, rlpEncodedStorageProof: hopRlpEncodedStorageProof } = await this.encodedStorageProof({
        msgHash: signalRoot,
        clientChainId: hop.chainId,
        contractAddress: hop.taikoAddress,
        proofForAccountAddress: hop.signalServiceAddress,
        blockNumber: blockNumber,
      });
      log('successfully generated hop storage proof', hopProof.storageHash);

      hops.push({
        signalRootRelay: hop.taikoAddress,
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
    const destCrossChainSyncAddress = routingContractsMap[destChainId][srcChainId].taikoAddress;

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

  _encodeAbiParameters(crossChainSync: string, height: bigint, storageProof: Hex, hops: Hop[]) {
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
