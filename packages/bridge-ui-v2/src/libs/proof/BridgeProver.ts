import { type Address, encodeAbiParameters, type Hash, type Hex, toHex } from 'viem';

import { routingContractsMap } from '$bridgeConfig';
import { MessageStatus } from '$libs/bridge';
import { InvalidProofError } from '$libs/error';

import { Prover } from './Prover';

export class BridgeProver extends Prover {
  constructor() {
    super();
  }

  // Reference: EncodedSignalProof in relayer/proof/encoded_signal_proof.go
  // protocol/contracts/signal/SignalService.sol
  private _encodedSignalProof(crossChainSyncAddress: Address, rlpEncodedStorageProof: Hex, blockHeight: bigint) {
    type Hop = {
      signalRootRelay: Address;
      signalRoot: Hex;
      storageProof: Hex;
    };

    const hops: Hop[] = [];
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
          crossChainSync: crossChainSyncAddress,
          height: blockHeight,
          storageProof: rlpEncodedStorageProof,
          hops: hops,
        },
      ],
    );

    return signalProof;
  }

  async encodedSignalProof(msgHash: Hash, srcChainId: number, destChainId: number) {
    const srcBridgeAddress = routingContractsMap[srcChainId][destChainId].bridgeAddress;
    const srcSignalServiceAddress = routingContractsMap[srcChainId][destChainId].signalServiceAddress;
    const destCrossChainSyncAddress = routingContractsMap[destChainId][srcChainId].crossChainSyncAddress;

    const { rlpEncodedStorageProof, block } = await this.encodedStorageProof({
      msgHash,
      clientChainId: srcChainId,
      contractAddress: srcBridgeAddress,
      crossChainSyncChainId: destChainId,
      proofForAccountAddress: srcSignalServiceAddress,
    });

    return this._encodedSignalProof(destCrossChainSyncAddress, rlpEncodedStorageProof, block.number as bigint);
  }

  async generateProofToRelease(msgHash: Hash, srcChainId: number, destChainId: number) {
    const srcBridgeAddress = routingContractsMap[srcChainId][destChainId].bridgeAddress;
    const destBridgeAddress = routingContractsMap[destChainId][srcChainId].bridgeAddress;
    const srcCrossChainSyncAddress = routingContractsMap[srcChainId][destChainId].crossChainSyncAddress;

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

    return this._encodedSignalProof(srcCrossChainSyncAddress, rlpEncodedStorageProof, block.number as bigint);
  }
}
