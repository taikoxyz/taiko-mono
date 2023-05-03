import { BigNumber, Contract, errors, type Signer, type Transaction } from 'ethers'

import { BRIDGE_ABI, ERC20_ABI, TOKEN_VAULT_ABI } from '../../abi'
import type { ChainsRecord } from '../chain/types'
import { MessageOwnerError } from '../message/MessageOwnerError'
import { MessageStatusError } from '../message/MessageStatusError'
import { type Message, MessageStatus } from '../message/types'
import type { Prover } from '../prover'
import type { GenerateProofArgs, GenerateReleaseProofArgs } from '../prover/types'
import { AllowanceError, AllowanceErrorCause } from './AllowanceError'
import type { ApproveArgs, Bridge, ClaimArgs, ERC20BridgeArgs, ReleaseArgs } from './types'

export class ERC20Bridge implements Bridge {
  private readonly prover: Prover
  private readonly chains: ChainsRecord

  constructor(prover: Prover, chains: ChainsRecord) {
    this.prover = prover
    this.chains = chains
  }

  private static async _prepareTransaction(args: ERC20BridgeArgs) {
    const tokenVaultContract = new Contract(args.tokenVaultAddress, TOKEN_VAULT_ABI, args.signer)

    const owner = await args.signer.getAddress()

    const message: Message = {
      sender: owner,
      srcChainId: args.srcChainId,
      destChainId: args.destChainId,
      owner: owner,
      to: args.to,
      refundAddress: owner,
      depositValue: args.amountInWei,
      callValue: BigNumber.from(0),
      processingFee: args.processingFeeInWei ?? BigNumber.from(0),
      gasLimit: args.processingFeeInWei ? BigNumber.from(140000) : BigNumber.from(0), // TODO: 140k ??
      memo: args.memo ?? '',
    }

    if (!args.isBridgedTokenAlreadyDeployed) {
      message.gasLimit = message.gasLimit.add(BigNumber.from(3000000)) // TODO: 3M ??
    }

    return { tokenVaultContract, owner, message }
  }

  private static async _spenderRequiresAllowance(
    tokenAddress: string,
    signer: Signer,
    amount: BigNumber,
    bridgeAddress: string,
  ): Promise<boolean> {
    const tokenContract = new Contract(tokenAddress, ERC20_ABI, signer)
    const owner = await signer.getAddress()
    const allowance: BigNumber = await tokenContract.allowance(owner, bridgeAddress)

    return allowance.lt(amount)
  }

  static requiresAllowance(args: ApproveArgs) {
    return ERC20Bridge._spenderRequiresAllowance(args.tokenAddress, args.signer, args.amountInWei, args.spenderAddress)
  }

  static async approve(args: ApproveArgs): Promise<Transaction> {
    const requiresAllowance = await ERC20Bridge._spenderRequiresAllowance(
      args.tokenAddress,
      args.signer,
      args.amountInWei,
      args.spenderAddress,
    )

    if (!requiresAllowance) {
      throw new AllowanceError('TokenVault has already allowance', {
        cause: AllowanceErrorCause.ALREADY_HAS_ALLOWANCE,
      })
    }

    const contract = new Contract(args.tokenAddress, ERC20_ABI, args.signer)
    const tx: Transaction = await contract.approve(args.spenderAddress, args.amountInWei)

    return tx
  }

  async estimateGas(args: ERC20BridgeArgs): Promise<BigNumber> {
    const { tokenVaultContract, message } = await ERC20Bridge._prepareTransaction(args)

    const gasEstimate = await tokenVaultContract.estimateGas.sendERC20(
      message.destChainId,
      message.to,
      args.tokenAddress,
      args.amountInWei,
      message.gasLimit,
      message.processingFee,
      message.refundAddress,
      message.memo,
      { value: message.processingFee.add(message.callValue) },
    )

    return gasEstimate
  }

  async bridge(args: ERC20BridgeArgs): Promise<Transaction> {
    const requiresAllowance = await ERC20Bridge._spenderRequiresAllowance(
      args.tokenAddress,
      args.signer,
      args.amountInWei,
      args.tokenVaultAddress,
    )

    if (requiresAllowance) {
      throw new AllowanceError('TokenVault requires allowance', {
        cause: AllowanceErrorCause.REQUIRES_ALLOWANCE,
      })
    }

    const { tokenVaultContract, message } = await ERC20Bridge._prepareTransaction(args)

    const tx: Transaction = await tokenVaultContract.sendERC20(
      message.destChainId,
      message.to,
      args.tokenAddress,
      args.amountInWei,
      message.gasLimit,
      message.processingFee,
      message.refundAddress,
      message.memo,
      { value: message.processingFee.add(message.callValue) },
    )

    return tx
  }

  async claim(args: ClaimArgs): Promise<Transaction> {
    const signerAddress = await args.signer.getAddress()

    if (args.message.owner.toLowerCase() !== signerAddress.toLowerCase()) {
      throw new MessageOwnerError('Cannot claim. Not the owner of the message')
    }

    const destBridgeContract = new Contract(args.destBridgeAddress, BRIDGE_ABI, args.signer)
    const messageStatus: MessageStatus = await destBridgeContract.getMessageStatus(args.msgHash)

    switch (messageStatus) {
      case MessageStatus.Done:
        throw new MessageStatusError('Message already processed')
      case MessageStatus.Failed:
        throw new MessageStatusError('Message already failed')
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

        if (args.message.gasLimit.gt(BigNumber.from(2500000))) {
          // TODO: 2.5M ??
          processMessageTx = await destBridgeContract.processMessage(args.message, proof, {
            gasLimit: args.message.gasLimit,
          })

          return processMessageTx
        }

        try {
          processMessageTx = await destBridgeContract.processMessage(args.message, proof)
        } catch (error) {
          if (error instanceof Error && 'code' in error && error.code === errors.UNPREDICTABLE_GAS_LIMIT) {
            processMessageTx = await destBridgeContract.processMessage(args.message, proof, { gasLimit: 1e6 })
          } else {
            throw error
          }
        }

        return processMessageTx
      }
      case MessageStatus.Retriable:
        return destBridgeContract.retryMessage(args.message, false)
      default:
        throw new MessageStatusError(`Unexpected message status: ${messageStatus}`)
    }
  }

  async release(args: ReleaseArgs): Promise<Transaction | undefined> {
    const signerAddress = await args.signer.getAddress()

    if (args.message.owner.toLowerCase() !== signerAddress.toLowerCase()) {
      throw new MessageOwnerError('Cannot release. Not the owner of the message')
    }

    const destBridgeContract = new Contract(args.destBridgeAddress, BRIDGE_ABI, args.destProvider)
    const messageStatus: MessageStatus = await destBridgeContract.getMessageStatus(args.msgHash)

    switch (messageStatus) {
      case MessageStatus.Done:
        throw new MessageStatusError('Message already processed')
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

        const srcTokenVaultContract = new Contract(args.srcTokenVaultAddress, TOKEN_VAULT_ABI, args.signer)

        return srcTokenVaultContract.releaseERC20(args.message, proof)
      }
      default:
        throw new MessageStatusError(`Unexpected message status: ${messageStatus}`)
    }
  }
}
