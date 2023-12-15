import { getContract, type GetContractResult, type PublicClient } from '@wagmi/core';
import { type Address, encodeAbiParameters, encodePacked, type Hex, keccak256, toHex, toRlp, type TransactionReceipt } from 'viem';
import type { Hash } from '@wagmi/core';

import { crossChainSyncABI } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { MessageStatus } from '$libs/bridge';
import { InvalidProofError, PendingBlockError } from '$libs/error';
import { getLogger } from '$libs/util/logger';
import { publicClient } from '$libs/wagmi';

import type { ClientWithEthGetProofRequest, GenerateProofArgs,  } from './types';

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
    console.log("syncedSnippet", syncedSnippet);
    const latestBlockHash = syncedSnippet['blockHash'];
    return client.getBlock({ blockHash: latestBlockHash });
  }

  protected async getBlockFromGetSyncedSnippet(
    client: PublicClient,
    crossChainSyncContract: GetContractResult<typeof crossChainSyncABI>,
    blockNumber: number,
  ) {
    console.log("getBlockFromGetSyncedSnippet", crossChainSyncContract)
    const syncedSnippet = await crossChainSyncContract.read.getSyncedSnippet([BigInt(blockNumber)]);
    console.log("getBlockFromGetSyncedSnippet", syncedSnippet);
    const latestBlockHash = syncedSnippet['blockHash'];
    const block = await client.getBlock({ blockHash: latestBlockHash });
    return {block, syncedSnippet}
  }

  async getBlockNumber(srcChainId: number, destChainId: number, blockNumber: number) {

    const destCrossChainSyncAddress = routingContractsMap[destChainId][srcChainId].taikoAddress;

    const crossChainSyncContract = getContract({
      chainId: destChainId,
      address: destCrossChainSyncAddress,
      abi: crossChainSyncABI,
    });

    console.log("crossChainSyncChainId", destChainId);
    console.log("clientChainId", srcChainId);
    console.log("blockNumber", blockNumber);

    const client = publicClient({ chainId: srcChainId });
    const {block, syncedSnippet} = await this.getBlockFromGetSyncedSnippet(client, crossChainSyncContract, blockNumber);
    return {block, syncedSnippet};
  }

  async encodedStorageProof(args: GenerateProofArgs) {
    console.log("encodedStorageProof args", args);
    let { msgHash, clientChainId, contractAddress, proofForAccountAddress, blockNumber } = args;
    const client = publicClient({ chainId: clientChainId });
    let key = await this.getSignalSlot(clientChainId, contractAddress, msgHash);

    console.log("encodedStorageProof key", key);

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

    console.log('Proof from eth_getProof', proof);

    if (proof.storageProof[0].value !== toHex(true)) {
      throw new InvalidProofError('storage proof value is not 1');
    }

    // RLP encode the proof together for LibTrieProof to decode
    const rlpEncodedStorageProof = toRlp(proof.storageProof[0].proof);

    return { proof, rlpEncodedStorageProof };
  }

  // Reference: EncodedSignalProof in relayer/proof/encoded_signal_proof.go
  // protocol/contracts/signal/SignalService.sol
  async encodedSignalProof(msgHash: Hash, srcChainId: number, destChainId: number) {
    console.log("encodedSignalProof");

    const srcBridgeAddress = routingContractsMap[srcChainId][destChainId].bridgeAddress;
    const srcSignalServiceAddress = routingContractsMap[srcChainId][destChainId].signalServiceAddress;
    const destCrossChainSyncAddress = routingContractsMap[destChainId][srcChainId].taikoAddress;

    // Get the block from chain A based on the latest block hash
    // we get cross chain (Taiko contract on chain B)
    const crossChainSyncContract = getContract({
      chainId: destChainId,
      address: destCrossChainSyncAddress,
      abi: crossChainSyncABI,
    });

    console.log("crossChainSyncChainId", destChainId);
    console.log("clientChainId", srcChainId);

    const client = publicClient({ chainId: srcChainId });

    const block = await this.getLatestBlockFromGetSyncedSnippet(client, crossChainSyncContract);
    if (block.hash === null || block.number === null) {
      throw new PendingBlockError('block is pending');
    }

    const { rlpEncodedStorageProof } = await this.encodedStorageProof({
      msgHash,
      clientChainId: srcChainId,
      contractAddress: srcBridgeAddress,
      proofForAccountAddress: srcSignalServiceAddress,
      blockNumber: block.number
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

  async encodedSignalProofWithHops(msgHash: Hash, receipt: TransactionReceipt, srcChainId: number, destChainId: number) {
    console.log("encodedSignalProofWithHops receipt", receipt);

    const srcBridgeAddress = routingContractsMap[srcChainId][destChainId].bridgeAddress;
    const srcSignalServiceAddress = routingContractsMap[srcChainId][destChainId].signalServiceAddress;
    const destCrossChainSyncAddress = routingContractsMap[destChainId][srcChainId].taikoAddress;

    const hopChainId = 31336;
    const hopTaikoAddresses = routingContractsMap[srcChainId][destChainId].hopTaikoAddresses;
    const hopSignalServiceAddresses = routingContractsMap[srcChainId][destChainId].hopSignalServiceAddresses;

    // let {block: block, syncedSnippet: syncedSnippet} = await this.getBlockNumber(srcChainId, hopChainId, receipt.blockNumber);
    // console.log("block123", block, syncedSnippet);

    // Get the block number from hop chain to dest chain
    const crossChainSyncContract = getContract({
      chainId: destChainId,
      address: destCrossChainSyncAddress,
      abi: crossChainSyncABI,
    });
    const hopClient = publicClient({ chainId: hopChainId });
    let block = await this.getLatestBlockFromGetSyncedSnippet(hopClient, crossChainSyncContract);
    if (block.hash === null || block.number === null) {
      throw new PendingBlockError('block is pending');
    }
    let blockNumber = block.number
    console.log("block123 blockNumber", blockNumber)

    // Generate main storage proof
    // Use receipt.blockNumber
    const { proof, rlpEncodedStorageProof } = await this.encodedStorageProof({
      msgHash,
      clientChainId: srcChainId,
      contractAddress: srcBridgeAddress,
      proofForAccountAddress: srcSignalServiceAddress,
      blockNumber: receipt.blockNumber,
    });

    // The first signalRoot
    const signalRoot = proof.storageHash;
    console.log("successfully generated main storage proof. singalRoot", signalRoot);

    const { proof: hopProof, rlpEncodedStorageProof: hopRlpEncodedStorageProof } = await this.encodedStorageProof({
      msgHash: signalRoot,
      clientChainId: hopChainId,
      contractAddress: hopTaikoAddresses,
      proofForAccountAddress: hopSignalServiceAddresses,
      blockNumber: blockNumber,
    });

    console.log("successfully generated hop storage proof. singalRoot");

    type Hop = {
      signalRootRelay: Address;
      signalRoot: Hex;
      storageProof: Hex;
    };

    // Create hopParams
    const hop: Hop = {
      signalRootRelay: hopTaikoAddresses,
      signalRoot: signalRoot,
      storageProof: hopRlpEncodedStorageProof,
    }
    const hops: Hop[] = [hop];

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
          height: blockNumber as bigint,
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

    const { proof, rlpEncodedStorageProof } = await this.encodedStorageProof({
      msgHash,
      clientChainId: destChainId,
      contractAddress: srcBridgeAddress,
      proofForAccountAddress: destBridgeAddress,
      blockNumber: "",
    });

    // Value must be 0x3 => MessageStatus.FAILED
    if (proof.storageProof[0].value !== toHex(MessageStatus.FAILED)) {
      throw new InvalidProofError('storage proof value is not FAILED');
    }

    // return this._encodedSignalProof(srcCrossChainSyncAddress, rlpEncodedStorageProof, block.number as bigint);
    return toHex('0x');
  }
}
