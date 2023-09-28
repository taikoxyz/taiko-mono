import { getContract, type GetContractResult, type PublicClient } from '@wagmi/core';
import { type Address, encodePacked, type Hex, keccak256, toHex } from 'viem';

import { crossChainSyncABI } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { PendingBlockError } from '$libs/error';
import { getLogger } from '$libs/util/logger';
import { publicClient } from '$libs/wagmi';

import type { Block, ClientWithEthGetProofRequest, GenerateProofArgs } from './types';

const log = getLogger('proof:Prover');

export class Prover {
  protected async _getKeyToClaim(contractAddress: Address, msgHash: Hex) {
    return keccak256(encodePacked(['address', 'bytes32'], [contractAddress, msgHash]));
  }

  protected async _getKeyToRecall(msgHash: Hex) {
    return keccak256(encodePacked(['bytes', 'bytes32'], [toHex('MESSAGE_STATUS'), msgHash]));
  }

  protected async _getLatestBlock(
    client: PublicClient,
    crossChainSyncContract: GetContractResult<typeof crossChainSyncABI>,
  ): Promise<Block> {
    const latestBlockHash = await crossChainSyncContract.read.getCrossChainBlockHash([BigInt(0)]);

    return await client.request({
      method: 'eth_getBlockByHash',
      params: [latestBlockHash, true],
    });
  }

  async generateRecallProof(args: GenerateProofArgs) {
    const { msgHash, srcChainId, destChainId, proofForAccountAddress } = args;
    const key = await this._getKeyToRecall(msgHash);
    log('key to recall', key);

    const destClient = publicClient({ chainId: destChainId });
    const crossChainSyncAddress = routingContractsMap[srcChainId][destChainId].crossChainSyncAddress;

    const crossChainSyncContract = getContract({
      chainId: srcChainId,
      address: crossChainSyncAddress,
      abi: crossChainSyncABI,
    });

    const block = await this._getLatestBlock(destClient, crossChainSyncContract);
    log('retrieved block', block);

    const clientWithEthProofRequest = destClient as ClientWithEthGetProofRequest;

    if (!block) throw new Error('could not fetch block');

    if (!block || !block.hash) {
      throw new Error('block  is null');
    }
    const proof = await clientWithEthProofRequest.request({
      method: 'eth_getProof',
      params: [
        // Address of the account to get the proof for
        proofForAccountAddress,

        // Array of storage-keys that should be proofed and included
        [key],

        'latest', //todo: why does it not work with block.hash?
      ],
    });
    return { proof, block };
  }

  async generateClaimProof(args: GenerateProofArgs) {
    const { msgHash, srcChainId, contractAddress, destChainId, proofForAccountAddress } = args;

    const crossChainSyncAddress = routingContractsMap[destChainId][srcChainId].crossChainSyncAddress;

    // Get the block from chain A based on the latest block hash
    // we get cross chain (Taiko contract on chain B)
    const crossChainSyncContract = getContract({
      chainId: destChainId,
      address: crossChainSyncAddress,
      abi: crossChainSyncABI,
    });

    const client = publicClient({ chainId: srcChainId });
    const block = await this._getLatestBlock(client, crossChainSyncContract);

    if (!block) throw new Error('could not fetch block');

    if (block.hash === null || block.number === null) {
      throw new PendingBlockError('block is pending');
    }

    const key = await this._getKeyToClaim(contractAddress, msgHash);

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

    return { proof, block };
  }
}
