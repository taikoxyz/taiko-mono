import { getContract, type GetContractResult, type PublicClient } from '@wagmi/core';
import { type Address, encodePacked, type Hex, keccak256, toHex, toRlp } from 'viem';

import { crossChainSyncABI } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { InvalidProofError, PendingBlockError } from '$libs/error';
import { getLogger } from '$libs/util/logger';
import { publicClient } from '$libs/wagmi';

import type { ClientWithEthGetProofRequest, GenerateProofArgs } from './types';

const log = getLogger('proof:Prover');

export class Prover {
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

    const crossChainSyncAddress = routingContractsMap[crossChainSyncChainId][clientChainId].crossChainSyncAddress;

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

    log('Proof from eth_getProof', proof);

    if (proof.storageProof[0].value !== toHex(true)) {
      throw new InvalidProofError('storage proof value is not 1');
    }

    // RLP encode the proof together for LibTrieProof to decode
    const rlpEncodedStorageProof = toRlp(proof.storageProof[0].proof);

    return { proof, rlpEncodedStorageProof, block };
  }
}
