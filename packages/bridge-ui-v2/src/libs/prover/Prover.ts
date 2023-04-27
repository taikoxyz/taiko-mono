import { Contract, ethers, type providers } from 'ethers'

import { XCHAIN_SYNC_ABI } from '../../abi'
import type { Block, BlockAndHeader, BlockHeader } from '../block/types'
import { MessageStatus } from '../message/types'
import type { ProvidersRecord } from '../provider/types'
import { InvalidProofError } from './InvalidProofError'
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
    xChainSyncContract: Contract,
    provider: providers.JsonRpcProvider,
  ): Promise<BlockAndHeader> {
    const latestBlockHash = await xChainSyncContract.getXchainBlockHash(0) // 0 => latest block

    // See https://docs.infura.io/infura/networks/ethereum/json-rpc-methods/eth_getblockbyhash
    const block: Block = await provider.send('eth_getBlockByHash', [latestBlockHash, false])

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

    const destXChainSyncContract = new Contract(args.destXChainSyncAddress, XCHAIN_SYNC_ABI, destProvider)

    const { block, blockHeader } = await Prover._getBlockAndBlockHeader(destXChainSyncContract, srcProvider)

    // RPC call to get the merkle proof what value is at key on the SignalService contract
    // See https://docs.infura.io/infura/networks/ethereum/json-rpc-methods/eth_getproof
    const proof: EthGetProofResponse = await srcProvider.send('eth_getProof', [
      args.srcSignalServiceAddress,
      [key],
      block.hash,
    ])

    const messageStatusRetriable = `0x${MessageStatus.Retriable}`
    if (proof.storageProof[0].value !== messageStatusRetriable) {
      throw new InvalidProofError('Invalid proof to claim')
    }

    return Prover._getSignalProof(proof, blockHeader)
  }

  async generateReleaseProof(args: GenerateReleaseProofArgs): Promise<string> {
    const key = Prover._getKey(args.sender, args.msgHash)

    const srcProvider = this.providers[args.srcChainId]
    const destProvider = this.providers[args.destChainId]

    const srcXChainSyncContract = new ethers.Contract(args.srcXChainSyncAddress, XCHAIN_SYNC_ABI, srcProvider)

    const { block, blockHeader } = await Prover._getBlockAndBlockHeader(srcXChainSyncContract, destProvider)

    // RPC call to get the merkle proof what value is at key on the SignalService contract
    const proof: EthGetProofResponse = await destProvider.send('eth_getProof', [
      args.destBridgeAddress,
      [key],
      block.hash,
    ])

    const messageStatusFailed = `0x${MessageStatus.Failed}`
    if (proof.storageProof[0].value !== messageStatusFailed) {
      throw new InvalidProofError('Invalid proof to release')
    }

    return Prover._getSignalProof(proof, blockHeader)
  }
}
