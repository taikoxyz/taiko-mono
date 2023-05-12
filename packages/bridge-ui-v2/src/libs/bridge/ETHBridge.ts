import { BigNumber, Contract, errors, type Transaction } from 'ethers'

import { bridgeABI } from '../../abi'
import type { ChainsRecord } from '../chain/types'
import { MessageOwnerError, MessageOwnerErrorCause } from '../message/MessageOwnerError'
import { MessageStatusError, MessageStatusErrorCause } from '../message/MessageStatusError'
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
    const bridgeContract = new Contract(args.bridgeAddress, bridgeABI, args.signer)

    const owner = await args.signer.getAddress()

    // TODO: understand the reason for these conditions
    const depositValue = args.to.toLowerCase() === owner.toLowerCase() ? args.amountInWei : BigNumber.from(0)
    const callValue = args.to.toLowerCase() === owner.toLowerCase() ? BigNumber.from(0) : args.amountInWei
    const processingFee = args.processingFeeInWei ?? BigNumber.from(0)
    const gasLimit = args.processingFeeInWei ? BigNumber.from(140000) : BigNumber.from(0) // TODO: 140k ??

    const message: Message = {
      owner,
      sender: owner,
      refundAddress: owner,

      to: args.to,
      srcChainId: args.srcChainId,
      destChainId: args.destChainId,

      depositValue,
      callValue,
      processingFee,
      gasLimit,

      memo: args.memo ?? '',
      id: 1, // will be set in contract,
      data: '0x',
    }

    return { bridgeContract, owner, message }
  }

  static async estimateGas(args: ETHBridgeArgs): Promise<BigNumber> {
    const { bridgeContract, message } = await ETHBridge._prepareTransaction(args)

    // See https://docs.ethers.org/v5/api/contract/contract/#contract-estimateGas
    const gasEstimate = await bridgeContract.estimateGas.sendMessage(message, {
      value: message.depositValue.add(message.processingFee).add(message.callValue),
    })

    return gasEstimate
  }

  static async bridge(args: ETHBridgeArgs): Promise<Transaction> {
    const { bridgeContract, message } = await ETHBridge._prepareTransaction(args)

    const tx: Transaction = await bridgeContract.sendMessage(message, {
      value: message.depositValue.add(message.processingFee).add(message.callValue),
    })

    return tx
  }

  async claim(args: ClaimArgs): Promise<Transaction> {
    const signerAddress = await args.signer.getAddress()

    if (args.message.owner.toLowerCase() !== signerAddress.toLowerCase()) {
      throw new MessageOwnerError('Cannot claim. Not the owner of the message', {
        cause: MessageOwnerErrorCause.NO_MESSAGE_OWNER,
      })
    }

    const destBridgeContract = new Contract(args.destBridgeAddress, bridgeABI, args.signer)
    const messageStatus: MessageStatus = await destBridgeContract.getMessageStatus(args.msgHash)

    switch (messageStatus) {
      case MessageStatus.Done:
        throw new MessageStatusError('Message already processed', {
          cause: MessageStatusErrorCause.MESSAGE_ALREADY_PROCESSED,
        })
      case MessageStatus.Failed:
        throw new MessageStatusError('Message already failed', {
          cause: MessageStatusErrorCause.MESSAGE_ALREADY_FAILED,
        })
      case MessageStatus.New: {
        const srcChain = this.chains[args.message.srcChainId]
        const destChain = this.chains[args.message.destChainId]

        const proofArgs: GenerateProofArgs = {
          msgHash: args.msgHash,
          sender: args.srcBridgeAddress,
          srcChainId: args.message.srcChainId,
          destChainId: args.message.destChainId,
          srcBridgeAddress: args.srcBridgeAddress,
          destCrossChainSyncAddress: destChain.crossChainSyncAddress,
          srcSignalServiceAddress: srcChain.signalServiceAddress,
        }

        const proof = await this.prover.generateProof(proofArgs)

        let processMessageTx: Transaction

        try {
          processMessageTx = await destBridgeContract.processMessage(args.message, proof)
        } catch (error) {
          if (error instanceof Error && 'code' in error && error.code === errors.UNPREDICTABLE_GAS_LIMIT) {
            // See https://docs.ethers.org/v5/troubleshooting/errors/#help-UNPREDICTABLE_GAS_LIMIT

            // Let's try again with a higher gas limit
            processMessageTx = await destBridgeContract.processMessage(
              args.message,
              proof,
              { gasLimit: 1e6 }, // TODO: magic number
            )
          } else {
            // TODO: should be have a custom error here?
            //       UnknownError with { cause: error }
            throw error
          }
        }

        return processMessageTx
      }
      case MessageStatus.Retriable:
        return destBridgeContract.retryMessage(args.message, true)
      default:
        throw new MessageStatusError(`Unexpected message status: ${messageStatus}`, {
          cause: MessageStatusErrorCause.UNEXPECTED_MESSAGE_STATUS,
        })
    }
  }

  async release(args: ReleaseArgs): Promise<Transaction | undefined> {
    const signerAddress = await args.signer.getAddress()

    if (args.message.owner.toLowerCase() !== signerAddress.toLowerCase()) {
      throw new MessageOwnerError('Cannot release. Not the owner of the message', {
        cause: MessageOwnerErrorCause.NO_MESSAGE_OWNER,
      })
    }

    const destBridgeContract = new Contract(args.destBridgeAddress, bridgeABI, args.destProvider)
    const messageStatus: MessageStatus = await destBridgeContract.getMessageStatus(args.msgHash)

    switch (messageStatus) {
      case MessageStatus.Done:
        throw new MessageStatusError('Message already processed', {
          cause: MessageStatusErrorCause.MESSAGE_ALREADY_PROCESSED,
        })
      case MessageStatus.Failed: {
        const srcChain = this.chains[args.message.srcChainId]
        const destChain = this.chains[args.message.destChainId]

        const proofArgs: GenerateReleaseProofArgs = {
          srcChainId: args.message.srcChainId,
          destChainId: args.message.destChainId,
          msgHash: args.msgHash,
          sender: args.srcBridgeAddress,
          destBridgeAddress: args.destBridgeAddress,
          destCrossChainSyncAddress: destChain.crossChainSyncAddress,
          srcCrossChainSyncAddress: srcChain.crossChainSyncAddress,
        }

        const proof = await this.prover.generateReleaseProof(proofArgs)

        const srcBridgeContract = new Contract(args.srcBridgeAddress, bridgeABI, args.signer)

        return srcBridgeContract.releaseEther(args.message, proof)
      }
      default:
        throw new MessageStatusError(`Unexpected message status: ${messageStatus}`, {
          cause: MessageStatusErrorCause.UNEXPECTED_MESSAGE_STATUS,
        })
    }
  }
}
