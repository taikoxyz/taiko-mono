import { getContract, type GetContractResult, type PublicClient } from '@wagmi/core';
import { type Address, encodeAbiParameters, encodePacked, type Hash, type Hex, keccak256, toHex, toRlp } from 'viem';

import { crossChainSyncABI } from '$abi';
import { MessageStatus } from '$libs/bridge';
import { chainContractsMap } from '$libs/chain';
import { InvalidProofError, PendingBlockError } from '$libs/error';
import { getLogger } from '$libs/util/logger';
import { publicClient } from '$libs/wagmi';

import type { ClientWithEthGetProofRequest, EthGetProofResponse } from './types';

const log = getLogger('proof:Prover');

// TODO: make a general Prover that can be reused for other things, not just the bridge,
//       with a specific bridge proof service that can generate a proof to claim and release.
export class Prover {
  private static async _getKey(sender: Address, msgHash: Hex) {
    return keccak256(encodePacked(['address', 'bytes32'], [sender, msgHash]));
  }

  private static async _getLatestBlock(
    client: PublicClient,
    crossChainSyncContract: GetContractResult<typeof crossChainSyncABI>,
  ) {
    const latestBlockHash = await crossChainSyncContract.read.getCrossChainBlockHash([BigInt(0)]);
    return client.getBlock({ blockHash: latestBlockHash });
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

  async generateProofToClaim(msgHash: Hash, srcChainId: number, destChainId: number) {
    const srcBridgeAddress = chainContractsMap[srcChainId].bridgeAddress;
    const srcSignalServiceAddress = chainContractsMap[srcChainId].signalServiceAddress;
    const destCrossChainSyncAddress = chainContractsMap[destChainId].crossChainSyncAddress;

    // Get the block from the source chain based on the latest block hash
    // we get cross chain (Taiko contract on the destination chain)
    const destCrossChainSyncContract = getContract({
      chainId: destChainId,
      address: destCrossChainSyncAddress,
      abi: crossChainSyncABI,
    });

    const srcClient = publicClient({ chainId: srcChainId });
    const block = await Prover._getLatestBlock(srcClient, destCrossChainSyncContract);

    if (block.hash === null || block.number === null) {
      throw new PendingBlockError('block is pending');
    }

    // sender => srcBridgeAddress
    const key = await Prover._getKey(srcBridgeAddress, msgHash);

    // Unfortunately, since this method is stagnant, it hasn't been included into Viem lib
    // as supported methods. Still stupported  by Alchmey, Infura and others.
    // See https://eips.ethereum.org/EIPS/eip-1186
    // Following is a workaround to support this method.
    const clientWithEthProofRequest = srcClient as ClientWithEthGetProofRequest;

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

    return Prover._getSignalProof(proof, block.number);
  }

  async generateProofToRelease(msgHash: Hash, srcChainId: number, destChainId: number) {
    const srcBridgeAddress = chainContractsMap[srcChainId].bridgeAddress;
    const destBridgeAddress = chainContractsMap[destChainId].bridgeAddress;
    const srcCrossChainSyncAddress = chainContractsMap[srcChainId].crossChainSyncAddress;

    // Get the block from the destination chain based on the latest block hash
    // we get cross chain (Taiko contract on the source chain)

    const srcCrossChainSyncContract = getContract({
      chainId: srcChainId,
      address: srcCrossChainSyncAddress,
      abi: crossChainSyncABI,
    });

    const destClient = publicClient({ chainId: destChainId });
    const block = await Prover._getLatestBlock(destClient, srcCrossChainSyncContract);

    if (block.hash === null || block.number === null) {
      throw new PendingBlockError('block is pending');
    }

    // sender => srcBridgeAddress
    const key = await Prover._getKey(srcBridgeAddress, msgHash);

    const clientWithEthProofRequest = destClient as ClientWithEthGetProofRequest;

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

    return Prover._getSignalProof(proof, block.number);
  }
}
