import { Contract, ethers, type providers } from 'ethers'

import { HEADER_SYNC_ABI } from '../../abi'
import type { Block, BlockAndHeader, BlockHeader } from '../block/types'
import type { ProvidersRecord } from '../provider/types'
import type { EthGetProofResponse, GenerateProofArgs, GenerateReleaseProofArgs } from './types'

const { defaultAbiCoder, keccak256, RLP, solidityPack } = ethers.utils

export class Prover {
  private readonly providers: ProvidersRecord

  constructor(providers: ProvidersRecord) {
    this.providers = providers
  }

  private static _getKey(sender: string, msgHash: string) {
    // See https://docs.ethers.org/v5/api/utils/hashing/#utils-solidityPack
    const packedValues = solidityPack(['address', 'bytes32'], [sender, msgHash])

    // See https://docs.ethers.org/v5/api/utils/hashing/#utils-keccak256
    return keccak256(packedValues)
  }

  private static async _getBlockAndBlockHeader(
    headerSyncContract: Contract,
    provider: providers.JsonRpcProvider,
  ): Promise<BlockAndHeader> {
    const latestSyncedHeader = await headerSyncContract.getLatestSyncedHeader()

    // See https://docs.infura.io/infura/networks/ethereum/json-rpc-methods/eth_getblockbyhash
    const block: Block = await provider.send('eth_getBlockByHash', [latestSyncedHeader, false])

    const processedLogsBloom = block.logsBloom
      .toString()
      .substring(2) // remove `0x` prefix
      .match(/.{1,64}/g) // splits into 64 character chunks
      ?.map((chunk: string) => `0x${chunk}`)

    const blockHeader: BlockHeader = {
      parentHash: block.parentHash,
      ommersHash: block.sha3Uncles,
      beneficiary: block.miner,
      stateRoot: block.stateRoot,
      transactionsRoot: block.transactionsRoot,
      receiptsRoot: block.receiptsRoot,
      logsBloom: processedLogsBloom ?? [],
      difficulty: block.difficulty,
      height: block.number,
      gasLimit: block.gasLimit,
      gasUsed: block.gasUsed,
      timestamp: block.timestamp,
      extraData: block.extraData,
      mixHash: block.mixHash,
      nonce: block.nonce,
      baseFeePerGas: block.baseFeePerGas ? parseInt(block.baseFeePerGas) : 0,
      withdrawalsRoot: block.withdrawalsRoot ?? ethers.constants.HashZero,
    }

    return { block, blockHeader }
  }

  private static _getSignalProof(proof: EthGetProofResponse, blockHeader: BlockHeader) {
    // RLP encode the proof together for LibTrieProof to decode
    // See https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/
    const encodedProof = RLP.encode(proof.storageProof[0].proof)

    // Encode the SignalProof struct from LibBridgeSignal
    // See https://docs.ethers.org/v5/api/utils/abi/coder/#AbiCoder--creating
    const signalProof = defaultAbiCoder.encode(
      [
        'tuple(tuple(bytes32 parentHash, bytes32 ommersHash, address beneficiary, bytes32 stateRoot, bytes32 transactionsRoot, bytes32 receiptsRoot, bytes32[8] logsBloom, uint256 difficulty, uint128 height, uint64 gasLimit, uint64 gasUsed, uint64 timestamp, bytes extraData, bytes32 mixHash, uint64 nonce, uint256 baseFeePerGas, bytes32 withdrawalsRoot) header, bytes proof)',
      ],
      [{ header: blockHeader, proof: encodedProof }],
    )

    return signalProof
  }

  async generateProof(args: GenerateProofArgs): Promise<string> {
    const key = Prover._getKey(args.sender, args.msgHash)

    const srcProvider = this.providers[args.srcChainId]
    const destProvider = this.providers[args.destChainId]

    const destHeaderSyncContract = new ethers.Contract(
      args.destHeaderSyncAddress,
      HEADER_SYNC_ABI,
      destProvider,
    )

    const { block, blockHeader } = await Prover._getBlockAndBlockHeader(
      destHeaderSyncContract,
      srcProvider,
    )

    // RPC call to get the merkle proof what value is at key on the SignalService contract
    // See https://docs.infura.io/infura/networks/ethereum/json-rpc-methods/eth_getproof
    const proof: EthGetProofResponse = await srcProvider.send('eth_getProof', [
      args.srcSignalServiceAddress,
      [key],
      block.hash,
    ])

    if (proof.storageProof[0].value !== '0x1') {
      throw Error('invalid proof')
    }

    return Prover._getSignalProof(proof, blockHeader)
  }

  async generateReleaseProof(args: GenerateReleaseProofArgs): Promise<string> {
    const key = Prover._getKey(args.sender, args.msgHash)

    const srcProvider = this.providers[args.srcChainId]
    const destProvider = this.providers[args.destChainId]

    const srcHeaderSyncContract = new ethers.Contract(
      args.srcHeaderSyncAddress,
      HEADER_SYNC_ABI,
      srcProvider,
    )

    const { block, blockHeader } = await Prover._getBlockAndBlockHeader(
      srcHeaderSyncContract,
      destProvider,
    )

    // RPC call to get the merkle proof what value is at key on the SignalService contract
    const proof: EthGetProofResponse = await destProvider.send('eth_getProof', [
      args.destBridgeAddress,
      [key],
      block.hash,
    ])

    if (proof.storageProof[0].value !== '0x3') {
      throw Error('invalid proof')
    }

    return Prover._getSignalProof(proof, blockHeader)
  }
}
