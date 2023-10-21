import { encodeAbiParameters, type Hash, toHex, toRlp } from 'viem';

import { routingContractsMap } from '$bridgeConfig';
import { MessageStatus } from '$libs/bridge';
import { InvalidProofError } from '$libs/error';

import { Prover } from './Prover';
import type { EthGetProofResponse } from './types';

export class BridgeProver extends Prover {
  constructor() {
    super();
  }

  private _getSignalProof(proof: EthGetProofResponse, blockHeight: bigint) {
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

  async generateProofToProcessMessage(msgHash: Hash, srcChainId: number, destChainId: number) {
    const srcBridgeAddress = routingContractsMap[srcChainId][destChainId].bridgeAddress;
    const srcSignalServiceAddress = routingContractsMap[srcChainId][destChainId].signalServiceAddress;

    const { proof, block } = await this.generateProof({
      msgHash,
      clientChainId: srcChainId,
      contractAddress: srcBridgeAddress,
      crossChainSyncChainId: destChainId,
      proofForAccountAddress: srcSignalServiceAddress,
    });

    // Value must be 0x1 => isSignalSent
    if (proof.storageProof[0].value !== toHex(true)) {
      throw new InvalidProofError('storage proof value is not 1');
    }

    return this._getSignalProof(proof, block.number as bigint);
  }

  async generateProofToRelease(msgHash: Hash, srcChainId: number, destChainId: number) {
    const srcBridgeAddress = routingContractsMap[srcChainId][destChainId].bridgeAddress;
    const destBridgeAddress = routingContractsMap[destChainId][srcChainId].bridgeAddress;

    const { proof, block } = await this.generateProof({
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

    return this._getSignalProof(proof, block.number as bigint);
  }
}
