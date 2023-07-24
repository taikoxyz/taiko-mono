import { getContract } from '@wagmi/core';
import { type Address, encodeAbiParameters, encodePacked, type Hex, keccak256, toRlp } from 'viem';

import { crossChainSyncABI } from '$abi';
import { InvalidProofError, PendingBlockError } from '$libs/error';
import { getLogger } from '$libs/util/logger';
import { publicClient } from '$libs/wagmi';

import type { ClientWithEthProofRequest, EthGetProofResponse, GenerateProofClaimArgs } from './types';

const log = getLogger('bridge:Prover');

export class Prover {
  private static async _getKey(sender: Address, msgHash: Hex) {
    return keccak256(encodePacked(['address', 'bytes32'], [sender, msgHash]));
  }

  private static async _getLatestBlock(crossChainSyncAddress: Address, srcChainId: number, destChainId: number) {
    const crossChainSyncContract = getContract({
      chainId: destChainId,
      address: crossChainSyncAddress,
      abi: crossChainSyncABI,
    });

    const latestBlockHash = await crossChainSyncContract.read.getCrossChainBlockHash([BigInt(0)]);

    return publicClient({ chainId: srcChainId }).getBlock({ blockHash: latestBlockHash });
  }

  private static _getSignalProof(proof: EthGetProofResponse, blockHeight: bigint) {
    // RLP encode the proof together for LibTrieProof to decode
    const encodedProof = toRlp(proof.storageProof[0].proof);

    // Encode the SignalProof struct:
    // struct SignalProof {
    //   uint256 height;
    //   bytes proof;
    // }
    const signalProof = encodeAbiParameters(
      // ['tuple(uint256 height, bytes proof)'],
      [
        {
          type: 'tuple',
          components: [
            { name: 'height', type: 'uint256' },
            { name: 'proof', type: 'bytes' },
          ],
        },
      ],
      [{ height: blockHeight, proof: encodedProof }],
    );

    return signalProof;
  }

  async generateProofToClaim({
    msgHash,
    chainId,
    sender,
    srcChainId,
    destChainId,
    destCrossChainSyncAddress,
    srcSignalServiceAddress,
  }: GenerateProofClaimArgs) {
    const key = await Prover._getKey(sender, msgHash);

    // Get the block from the source chain based on the latest block hash
    // we get cross chain (Taiko contract on the destination chain)
    const block = await Prover._getLatestBlock(destCrossChainSyncAddress, srcChainId, destChainId);

    if (block.hash === null || block.number === null) {
      throw new PendingBlockError('block is pending');
    }

    // Unfortunately, since this method is stagnant, it hasn't been included into Viem lib
    // as supported methods. Still stupported  by Alchmey, Infura and others.
    // See https://eips.ethereum.org/EIPS/eip-1186
    // Following is a workaround to support this method.
    const clientWithEthProofRequest = publicClient({ chainId }) as ClientWithEthProofRequest;

    // RPC call to get the merkle proof what value is at key on the SignalService contract
    const proof = await clientWithEthProofRequest.request({
      method: 'eth_getProof',
      params: [
        // Address of the account to get the proof for
        srcSignalServiceAddress,

        // Array of storage-keys that should be proofed and included
        [key],

        block.hash,
      ],
    });

    log('Proof from eth_getProof', proof);

    if (proof.storageProof[0].value !== '0x1') {
      throw new InvalidProofError('storage proof value is not 1');
    }

    return Prover._getSignalProof(proof, block.number);
  }
}
