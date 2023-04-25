import { Contract, type Transaction } from 'ethers'

import { BRIDGE_ABI } from '../../abi'
import type { ChainsRecord } from '../chain/types'
import { type Message, MessageStatus } from '../message/types'
import type { Prover } from '../prover'
import type { GenerateProofArgs } from '../prover/types'
import type { GenerateReleaseProofArgs } from '../prover/types'
import type { Bridge, ClaimArgs, ETHBridgeArgs, ReleaseArgs } from './types'

export class ETHBridge implements Bridge {
  private readonly prover: Prover
  private readonly chains: ChainsRecord

  constructor(prover: Prover, chains: ChainsRecord) {
    this.prover = prover
    this.chains = chains
  }

  private static async _prepareTransaction(args: ETHBridgeArgs) {
    const bridgeContract = new Contract(args.bridgeAddress, BRIDGE_ABI, args.signer)

    const owner = await args.signer.getAddress()

    const message: Message = {
      sender: owner,
      srcChainId: args.srcChainId,
      destChainId: args.destChainId,
      owner: owner,
      to: args.to,
      refundAddress: owner,
      depositValue: args.to.toLowerCase() === owner.toLowerCase() ? args.amountInWei : BigInt(0),
      callValue: args.to.toLowerCase() === owner.toLowerCase() ? BigInt(0) : args.amountInWei,
      processingFee: args.processingFeeInWei ?? BigInt(0),
      gasLimit: args.processingFeeInWei ? BigInt(140000) : BigInt(0), // TODO: 140k ??
      memo: args.memo ?? '',
      id: 1, // will be set in contract,
      data: '0x',
    }

    return { bridgeContract, owner, message }
  }

  async estimateGas(args: ETHBridgeArgs): Promise<bigint> {
    const { bridgeContract, message } = await ETHBridge._prepareTransaction(args)

    const gasEstimate = await bridgeContract.sendMessage.estimateGas(message, {
      value: message.depositValue + message.processingFee + message.callValue,
    })

    return gasEstimate
  }

  async bridge(args: ETHBridgeArgs): Promise<Transaction> {
    const { bridgeContract, message } = await ETHBridge._prepareTransaction(args)

    const tx: Transaction = await bridgeContract.sendMessage(message, {
      value: message.depositValue + message.processingFee + message.callValue,
    })

    return tx
  }

  async claim(args: ClaimArgs): Promise<Transaction> {
    const destBridgeContract = new Contract(args.destBridgeAddress, BRIDGE_ABI, args.signer)

    const messageStatus: MessageStatus = await destBridgeContract.getMessageStatus(args.msgHash)

    if (messageStatus === MessageStatus.Done) {
      throw Error('message already processed')
    }

    const signerAddress = await args.signer.getAddress()

    if (args.message.owner.toLowerCase() !== signerAddress.toLowerCase()) {
      throw Error('user can not process this, it is not their message')
    }

    if (messageStatus === MessageStatus.New) {
      const proofArgs: GenerateProofArgs = {
        msgHash: args.msgHash,
        sender: args.srcBridgeAddress,
        srcChainId: args.message.srcChainId,
        destChainId: args.message.destChainId,
        srcBridgeAddress: args.srcBridgeAddress,
        destHeaderSyncAddress: this.chains[args.message.destChainId].headerSyncAddress,
        srcSignalServiceAddress: this.chains[args.message.srcChainId].signalServiceAddress,
      }

      const proof = await this.prover.generateProof(proofArgs)

      let processMessageTx: Transaction

      try {
        processMessageTx = await destBridgeContract.processMessage(args.message, proof)
      } catch (error) {
        // TODO: this condition is a wrong at the moment
        if (error instanceof Error && error.name === 'UNPREDICTABLE_GAS_LIMIT') {
          processMessageTx = await destBridgeContract.processMessage(args.message, proof, {
            gasLimit: 1e6, // TODO: magic number
          })
        } else {
          throw Error(error as string)
        }
      }

      return processMessageTx
    } else {
      return destBridgeContract.retryMessage(args.message, true)
    }
  }

  async releaseTokens(args: ReleaseArgs): Promise<Transaction | undefined> {
    const destBridgeContract = new Contract(args.destBridgeAddress, BRIDGE_ABI, args.destProvider)

    const messageStatus: MessageStatus = await destBridgeContract.getMessageStatus(args.msgHash)

    if (messageStatus === MessageStatus.Done) {
      throw Error('message already processed')
    }

    const signerAddress = await args.signer.getAddress()

    if (args.message.owner.toLowerCase() !== signerAddress.toLowerCase()) {
      throw Error('user can not release these tokens, it is not their message')
    }

    if (messageStatus === MessageStatus.Failed) {
      const proofArgs: GenerateReleaseProofArgs = {
        srcChainId: args.message.srcChainId,
        destChainId: args.message.destChainId,
        msgHash: args.msgHash,
        sender: args.srcBridgeAddress,
        destBridgeAddress: args.destBridgeAddress,
        destHeaderSyncAddress: this.chains[args.message.destChainId].headerSyncAddress,
        srcHeaderSyncAddress: this.chains[args.message.srcChainId].headerSyncAddress,
      }

      const proof = await this.prover.generateReleaseProof(proofArgs)

      const srcBridgeContract = new Contract(args.srcBridgeAddress, BRIDGE_ABI, args.signer)

      return srcBridgeContract.releaseEther(args.message, proof)
    }
  }
}
