import { crossChainSyncABI } from "$abi";
import { publicClient } from "$libs/wagmi";
import { getContract } from "@wagmi/core";
import { keccak256, type Address, type Hex, encodePacked, toRlp, encodeAbiParameters } from "viem";
import type { ClientWithEthProofRequest, EthGetProofResponse, GenerateProofArgs } from "./types";
import { getLogger } from "$libs/logger";

const log = getLogger('bridge:Prover');

export class Prover {
  private static async _getKey(sender: Address, msgHash: Hex) {
    return keccak256(encodePacked(['address', 'bytes32'], [sender, msgHash]))
  }

  private static async _getLatestBlock(crossChainSyncAddress: Address, chainId: number) {
    const crossChainSyncContract = getContract({
      chainId,
      address: crossChainSyncAddress,
      abi: crossChainSyncABI
    })

    const latestBlockHash = await crossChainSyncContract.read.getCrossChainBlockHash([BigInt(0)]);

    return publicClient({ chainId }).getBlock({ blockHash: latestBlockHash });
  }

  private static _getSignalProof(
    proof: EthGetProofResponse,
    blockHeight: number,
  ) {
    // RLP encode the proof together for LibTrieProof to decode
    const encodedProof = toRlp(proof.storageProof[0].proof);

    // Encode the SignalProof struct:
    // struct SignalProof {
    //   uint256 height;
    //   bytes proof;
    // }
    const signalProof = encodeAbiParameters(
      ['tuple(uint256 height, bytes proof)'],
      [{ height: blockHeight, proof: encodedProof }],
    );

    return signalProof;
  }

  async generateProof({msgHash, chainId, sender, crossChainSyncAddress, signalServiceAddress}: GenerateProofArgs) {
    const key = await Prover._getKey(sender, msgHash);
    const block = await Prover._getLatestBlock(crossChainSyncAddress, chainId);

    publicClient({ chainId }).getStorageAt

      // Unfortunately, since this method is stagnant, it hasn't been included into Viem lib
      // as supported methods. Still stupported  by Alchmey, Infura and others.
      // See https://eips.ethereum.org/EIPS/eip-1186
      // Following is a workaround to support this method.
    const clientWithEthProofRequest = publicClient({ chainId }) as ClientWithEthProofRequest

    // RPC call to get the merkle proof what value is at key on the SignalService contract
    const proof = await clientWithEthProofRequest.request({
      method: 'eth_getProof',
      params: [
        // Address of the account to get the proof for
        signalServiceAddress, 

        // Array of storage-keys that should be proofed and included
        [key], 

        block.hash
      ]
    })

    log('Proof from eth_getProof', proof);
  }
}
