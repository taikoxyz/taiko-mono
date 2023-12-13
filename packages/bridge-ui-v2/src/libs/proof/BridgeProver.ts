import { getContract, type GetContractResult, type PublicClient } from '@wagmi/core';
import { type Address, encodeAbiParameters, encodePacked, type Hash, type Hex, keccak256, toHex, toRlp } from 'viem';

import { crossChainSyncABI } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { MessageStatus } from '$libs/bridge';
import { InvalidProofError, PendingBlockError } from '$libs/error';
import { getLogger } from '$libs/util/logger';
import { publicClient } from '$libs/wagmi';

import type { ClientWithEthGetProofRequest, GenerateProofArgs } from './types';

const log = getLogger('proof:Prover');

export class BridgeProver {
  async getSignalSlot(chainId: number, contractAddress: Address, msgHash: Hex) {
    return keccak256(
      encodePacked(['string', 'uint64', 'address', 'bytes32'], ['SIGNAL', BigInt(chainId), contractAddress, msgHash]),
    );
  }

  protected async getLatestBlockFromGetSyncedSnippet(
    client: PublicClient,
    crossChainSyncContract: GetContractResult<typeof crossChainSyncABI>,
  ) {
    const syncedSnippet = await crossChainSyncContract.read.getSyncedSnippet([BigInt(0)]);
    const latestBlockHash = syncedSnippet['blockHash'];
    return client.getBlock({ blockHash: latestBlockHash });
  }

  async encodedStorageProof(args: GenerateProofArgs) {
    const { msgHash, clientChainId, contractAddress, crossChainSyncChainId, proofForAccountAddress } = args;

    const crossChainSyncAddress = routingContractsMap[crossChainSyncChainId][clientChainId].taikoAddress;

    // Get the block from chain A based on the latest block hash
    // we get cross chain (Taiko contract on chain B)
    const crossChainSyncContract = getContract({
      chainId: crossChainSyncChainId,
      address: crossChainSyncAddress,
      abi: crossChainSyncABI,
    });

    const client = publicClient({ chainId: clientChainId });
    const block = await this.getLatestBlockFromGetSyncedSnippet(client, crossChainSyncContract);

    if (block.hash === null || block.number === null) {
      throw new PendingBlockError('block is pending');
    }

    const key = await this.getSignalSlot(clientChainId, contractAddress, msgHash);

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

        block.hash,
      ],
    });

    console.log('Proof from eth_getProof', proof);

    if (proof.storageProof[0].value !== toHex(true)) {
      throw new InvalidProofError('storage proof value is not 1');
    }

    // RLP encode the proof together for LibTrieProof to decode
    const rlpEncodedStorageProof = toRlp(proof.storageProof[0].proof);

    return { proof, rlpEncodedStorageProof, block };
  }

  // Reference: EncodedSignalProof in relayer/proof/encoded_signal_proof.go
  // protocol/contracts/signal/SignalService.sol
  async encodedSignalProof(msgHash: Hash, srcChainId: number, destChainId: number) {
    const srcBridgeAddress = routingContractsMap[srcChainId][destChainId].bridgeAddress;
    const srcSignalServiceAddress = routingContractsMap[srcChainId][destChainId].signalServiceAddress;
    const destCrossChainSyncAddress = routingContractsMap[destChainId][srcChainId].taikoAddress;

    const { rlpEncodedStorageProof, block } = await this.encodedStorageProof({
      msgHash,
      clientChainId: srcChainId,
      contractAddress: srcBridgeAddress,
      crossChainSyncChainId: destChainId,
      proofForAccountAddress: srcSignalServiceAddress,
    });

    type Hop = {
      signalRootRelay: Address;
      signalRoot: Hex;
      storageProof: Hex;
    };

    const hops: Hop[] = [];
    // TODO: move to encodeAbiParameters for signalProof
    const signalProof = encodeAbiParameters(
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
          crossChainSync: destCrossChainSyncAddress,
          height: block.number as bigint,
          storageProof: rlpEncodedStorageProof,
          hops: hops,
        },
      ],
    );

    return signalProof;
  }

  async encodedSignalProofWithHops(msgHash: Hash, srcChainId: number, destChainId: number) {
    const srcBridgeAddress = routingContractsMap[srcChainId][destChainId].bridgeAddress;
    const srcSignalServiceAddress = routingContractsMap[srcChainId][destChainId].signalServiceAddress;
    const destCrossChainSyncAddress = routingContractsMap[destChainId][srcChainId].taikoAddress;

    const { proof, rlpEncodedStorageProof, block } = await this.encodedStorageProof({
      msgHash,
      clientChainId: srcChainId,
      contractAddress: srcBridgeAddress,
      crossChainSyncChainId: destChainId,
      proofForAccountAddress: srcSignalServiceAddress,
    });

    // The first signalRoot
    const signalRoot = proof.storageHash;

    type Hop = {
      signalRootRelay: Address;
      signalRoot: Hex;
      storageProof: Hex;
    };

    // Create hopParams
    const hops: Hop[] = [];

    // TODO: move to encodeAbiParameters for signalProof
    const signalProof = encodeAbiParameters(
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
          crossChainSync: destCrossChainSyncAddress,
          height: block.number as bigint,
          storageProof: rlpEncodedStorageProof,
          hops: hops,
        },
      ],
    );

    return signalProof;
  }

  // TODO: fix generateProofToRelease
  async generateProofToRelease(msgHash: Hash, srcChainId: number, destChainId: number) {
    const srcBridgeAddress = routingContractsMap[srcChainId][destChainId].bridgeAddress;
    const destBridgeAddress = routingContractsMap[destChainId][srcChainId].bridgeAddress;
    const srcCrossChainSyncAddress = routingContractsMap[srcChainId][destChainId].taikoAddress;

    const { proof, rlpEncodedStorageProof, block } = await this.encodedStorageProof({
      msgHash,
      clientChainId: destChainId,
      contractAddress: srcBridgeAddress,
      crossChainSyncChainId: srcChainId,
      proofForAccountAddress: destBridgeAddress,
    });

    // Value must be 0x3 => MessageStatus.FAILED
    if (proof.storageProof[0].value !== toHex(MessageStatus.FAILED)) {
      throw new InvalidProofError('storage proof value is not FAILED');
    }

    // return this._encodedSignalProof(srcCrossChainSyncAddress, rlpEncodedStorageProof, block.number as bigint);
    return toHex('0x');
  }
}
