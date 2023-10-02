import { encodeAbiParameters, getAddress, type Hash, type Hex, toHex, toRlp } from 'viem';

import { routingContractsMap } from '$bridgeConfig';
import { MessageStatus } from '$libs/bridge';
import { InvalidProofError } from '$libs/error';
import { generateZeroHex } from '$libs/util/genereateZeroHex';

import { Prover } from './Prover';
import type { Block, BlockHeader, EthGetProofResponse } from './types';

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

  private _encodeProofs(proof: EthGetProofResponse): Hex {
    // RLP encode the proof together for LibTrieProof to decode
    const encodedAccountProof = toRlp(proof.accountProof[0]);
    const encodedStorageProof = toRlp(proof.storageProof[0].proof);

    const params = [
      {
        name: 'encodedAccountProof',
        type: 'bytes',
      },
      {
        name: 'encodedStorageProof',
        type: 'bytes',
      },
    ];

    const encoded = encodeAbiParameters(params, [encodedAccountProof, encodedStorageProof]);
    return encoded;
  }

  private _getSignalProofForRelease(proof: EthGetProofResponse, blockHeader: BlockHeader): Hex {
    const encodedProofs = this._encodeProofs(proof);

    const params = [
      {
        name: '',
        type: 'tuple',
        components: [
          {
            name: 'header',
            type: 'tuple',
            components: [
              { name: 'parentHash', type: 'bytes32' },
              { name: 'ommersHash', type: 'bytes32' },
              { name: 'proposer', type: 'address' },
              { name: 'stateRoot', type: 'bytes32' },
              { name: 'transactionsRoot', type: 'bytes32' },
              { name: 'receiptsRoot', type: 'bytes32' },
              { name: 'logsBloom', type: 'bytes32[8]' },
              { name: 'difficulty', type: 'uint256' },
              { name: 'height', type: 'uint128' },
              { name: 'gasLimit', type: 'uint64' },
              { name: 'gasUsed', type: 'uint64' },
              { name: 'timestamp', type: 'uint64' },
              { name: 'extraData', type: 'bytes' },
              { name: 'mixHash', type: 'bytes32' },
              { name: 'nonce', type: 'uint64' },
              { name: 'baseFeePerGas', type: 'uint256' },
              { name: 'withdrawalsRoot', type: 'bytes32' },
            ],
          },
          {
            name: 'proof',
            type: 'bytes',
          },
        ],
      },
    ];

    const values = [[blockHeader, encodedProofs]];
    const signalProof = encodeAbiParameters(params, values);

    return signalProof;
  }

  async generateProofToProcessMessage(msgHash: Hash, srcChainId: number, destChainId: number) {
    const srcBridgeAddress = routingContractsMap[srcChainId][destChainId].bridgeAddress;
    const srcSignalServiceAddress = routingContractsMap[srcChainId][destChainId].signalServiceAddress;

    const { proof, block } = await this.generateClaimProof({
      msgHash,
      srcChainId,
      contractAddress: srcBridgeAddress,
      destChainId,
      proofForAccountAddress: srcSignalServiceAddress,
    });

    // Value must be 0x1 => isSignalSent
    if (proof.storageProof[0].value !== toHex(true)) {
      throw new InvalidProofError('storage proof value is not 1');
    }

    return this._getSignalProof(proof, BigInt(block.number));
  }

  async generateProofToRecallMessage(msgHash: Hash, srcChainId: number, destChainId: number) {
    const destBridgeAddress = routingContractsMap[destChainId][srcChainId].bridgeAddress;

    const { proof, block } = await this.generateRecallProof({
      msgHash,
      srcChainId,
      contractAddress: destBridgeAddress,
      destChainId,
      proofForAccountAddress: destBridgeAddress,
    });

    const blockHeader = buildBlockHeaderFromBlock(block);

    // Value must be 0x3 => MessageStatus.FAILED
    if (proof.storageProof[0].value !== toHex(MessageStatus.FAILED)) {
      throw new InvalidProofError('storage proof value is not FAILED');
    }

    const signalProof = this._getSignalProofForRelease(proof, blockHeader);
    return signalProof;
  }
}
const buildBlockHeaderFromBlock = (block: Block): BlockHeader => {
  let logsBloomArray: Hex[];
  let baseFeePerGas: bigint = BigInt(0);

  if (block.baseFeePerGas) {
    baseFeePerGas = BigInt(block.baseFeePerGas);
  }

  if (Array.isArray(block.logsBloom)) {
    logsBloomArray = block.logsBloom;
  } else {
    const logsBloomString = block.logsBloom.substring(2);
    logsBloomArray = logsBloomString.match(/.{1,64}/g)!.map((s) => `0x${s}`) as Hex[];
  }

  return {
    parentHash: block.parentHash,
    ommersHash: block.sha3Uncles,
    proposer: getAddress(block.miner),
    stateRoot: block.stateRoot,
    transactionsRoot: block.transactionsRoot,
    receiptsRoot: block.receiptsRoot,
    logsBloom: logsBloomArray,
    difficulty: block.difficulty,
    height: block.number ? BigInt(block.number) : BigInt(0),
    gasLimit: block.gasLimit,
    gasUsed: block.gasUsed,
    timestamp: block.timestamp,
    extraData: block.extraData,
    mixHash: block.mixHash,
    nonce: block.nonce,
    baseFeePerGas,
    withdrawalsRoot: block.withdrawalsRoot ? block.withdrawalsRoot : generateZeroHex(32),
  };
};
