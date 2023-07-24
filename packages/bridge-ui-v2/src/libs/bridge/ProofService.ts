import { getContract, type GetContractResult, type PublicClient } from '@wagmi/core';
import { type Address, encodeAbiParameters, encodePacked, type Hex, keccak256, toHex, toRlp } from 'viem';

import { crossChainSyncABI } from '$abi';
import { InvalidProofError, PendingBlockError } from '$libs/error';
import { getLogger } from '$libs/util/logger';
import { publicClient } from '$libs/wagmi';

import {
  type ClientWithEthGetProofRequest,
  type EthGetProofResponse,
  type GenerateProofClaimArgs,
  type GenerateProofReleaseArgs,
  MessageStatus,
} from './types';

const log = getLogger('bridge:Prover');

export class ProofService {
  private static async _getKey(sender: Address, msgHash: Hex) {
    return keccak256(encodePacked(['address', 'bytes32'], [sender, msgHash]));
  }

  private static async _getLatestBlock(
    crossChainSyncContract: GetContractResult<typeof crossChainSyncABI>,
    provider: PublicClient,
  ) {
    const latestBlockHash = await crossChainSyncContract.read.getCrossChainBlockHash([BigInt(0)]);
    return provider.getBlock({ blockHash: latestBlockHash });
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
    // Get the block from the source chain based on the latest block hash
    // we get cross chain (Taiko contract on the destination chain)

    const crossChainSyncContract = getContract({
      chainId: destChainId,
      address: destCrossChainSyncAddress,
      abi: crossChainSyncABI,
    });

    const provider = publicClient({ chainId: srcChainId });
    const block = await ProofService._getLatestBlock(crossChainSyncContract, provider);

    if (block.hash === null || block.number === null) {
      throw new PendingBlockError('block is pending');
    }

    const key = await ProofService._getKey(sender, msgHash);

    // Unfortunately, since this method is stagnant, it hasn't been included into Viem lib
    // as supported methods. Still stupported  by Alchmey, Infura and others.
    // See https://eips.ethereum.org/EIPS/eip-1186
    // Following is a workaround to support this method.
    const clientWithEthProofRequest = publicClient({ chainId }) as ClientWithEthGetProofRequest;

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

    // Value must be 0x1 => isSignalSent
    if (proof.storageProof[0].value !== toHex(true)) {
      throw new InvalidProofError('storage proof value is not 1');
    }

    return ProofService._getSignalProof(proof, block.number);
  }

  async generateProofToRelease({
    msgHash,
    chainId,
    sender,
    srcChainId,
    destChainId,
    destBridgeAddress,
    srcCrossChainSyncAddress,
  }: GenerateProofReleaseArgs) {
    // Get the block from the destination chain based on the latest block hash
    // we get cross chain (Taiko contract on the source chain)

    const crossChainSyncContract = getContract({
      chainId: srcChainId,
      address: srcCrossChainSyncAddress,
      abi: crossChainSyncABI,
    });

    const provider = publicClient({ chainId: destChainId });
    const block = await ProofService._getLatestBlock(crossChainSyncContract, provider);

    if (block.hash === null || block.number === null) {
      throw new PendingBlockError('block is pending');
    }

    const key = await ProofService._getKey(sender, msgHash);

    const clientWithEthProofRequest = publicClient({ chainId }) as ClientWithEthGetProofRequest;

    // RPC call to get the merkle proof what value is at key on the SignalService contract
    const proof = await clientWithEthProofRequest.request({
      method: 'eth_getProof',
      params: [
        // Address of the account to get the proof for
        destBridgeAddress,

        // Array of storage-keys that should be proofed and included
        [key],

        block.hash,
      ],
    });

    log('Proof from eth_getProof', proof);

    // Value must be 0x3 => MessageStatus.FAILED
    if (proof.storageProof[0].value !== toHex(MessageStatus.FAILED)) {
      throw new InvalidProofError('storage proof value is not FAILED');
    }

    return ProofService._getSignalProof(proof, block.number);
  }
}
