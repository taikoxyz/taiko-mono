import { BigNumber, Contract, Signer, type Transaction } from 'ethers'

import type { ChainsRecord } from '../chain/types'
import type { Prover } from '../prover'
import type { ERC20BridgeArgs, ApproveArgs } from './types'
import { ERC20_ABI, TOKEN_VAULT_ABI } from '../../abi'
import type { Message } from '../message/types'
import { AllowanceError } from './AllowanceError'

export class ERC20Bridge {
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
      throw new AllowanceError('TokenVauld has already allowance')
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
      {
        value: message.processingFee.add(message.callValue),
      },
    )

    return gasEstimate
  }

  async bridge(opts: ERC20BridgeArgs): Promise<Transaction> {
    if (await this.spenderRequiresAllowance(opts.tokenAddress, opts.signer, opts.amountInWei, opts.tokenVaultAddress)) {
      throw Error('token vault does not have required allowance')
    }

    const { contract, message } = await ERC20Bridge.prepareTransaction(opts)

    const tx = await contract.sendERC20(
      message.destChainId,
      message.to,
      opts.tokenAddress,
      opts.amountInWei,
      message.gasLimit,
      message.processingFee,
      message.refundAddress,
      message.memo,
      {
        value: message.processingFee.add(message.callValue),
      },
    )

    return tx
  }

  async Claim(opts: ClaimOpts): Promise<Transaction> {
    const contract: Contract = new Contract(opts.destBridgeAddress, BridgeABI, opts.signer)

    const messageStatus: MessageStatus = await contract.getMessageStatus(opts.msgHash)

    if (messageStatus === MessageStatus.Done || messageStatus === MessageStatus.Failed) {
      // TODO: should be throw a different error when status is Failed?
      throw Error('message already processed')
    }

    const signerAddress = await opts.signer.getAddress()

    if (opts.message.owner.toLowerCase() !== signerAddress.toLowerCase()) {
      throw Error('user can not process this, it is not their message')
    }

    if (messageStatus === MessageStatus.New) {
      const proof = await this.prover.generateProof({
        srcChain: opts.message.srcChainId,
        msgHash: opts.msgHash,
        sender: opts.srcBridgeAddress,
        srcBridgeAddress: opts.srcBridgeAddress,
        destChain: opts.message.destChainId,
        destHeaderSyncAddress: chains[opts.message.destChainId].headerSyncAddress,
        srcSignalServiceAddress: chains[opts.message.srcChainId].signalServiceAddress,
      })

      if (opts.message.gasLimit.gt(BigNumber.from(2500000))) {
        return await contract.processMessage(opts.message, proof, {
          gasLimit: opts.message.gasLimit,
        })
      }

      let processMessageTx
      try {
        processMessageTx = await contract.processMessage(opts.message, proof)
      } catch (error) {
        if (error.code === ethers.errors.UNPREDICTABLE_GAS_LIMIT) {
          processMessageTx = await contract.processMessage(opts.message, proof, {
            gasLimit: 1e6,
          })
        } else {
          throw new Error(error)
        }
      }
      return processMessageTx
    } else {
      return await contract.retryMessage(opts.message, false)
    }
  }

  async ReleaseTokens(opts: ReleaseOpts): Promise<Transaction> {
    const destBridgeContract: Contract = new Contract(opts.destBridgeAddress, BridgeABI, opts.destProvider)

    const messageStatus: MessageStatus = await destBridgeContract.getMessageStatus(opts.msgHash)

    if (messageStatus === MessageStatus.Done) {
      throw Error('message already processed')
    }

    const signerAddress = await opts.signer.getAddress()

    if (opts.message.owner.toLowerCase() !== signerAddress.toLowerCase()) {
      throw Error('user can not release these tokens, it is not their message')
    }

    if (messageStatus === MessageStatus.Failed) {
      const proofOpts = {
        srcChain: opts.message.srcChainId,
        msgHash: opts.msgHash,
        sender: opts.srcBridgeAddress,
        destBridgeAddress: opts.destBridgeAddress,
        destChain: opts.message.destChainId,
        destHeaderSyncAddress: chains[opts.message.destChainId].headerSyncAddress,
        srcHeaderSyncAddress: chains[opts.message.srcChainId].headerSyncAddress,
      }

      const proof = await this.prover.generateReleaseProof(proofOpts)

      const srcTokenVaultContract: Contract = new Contract(opts.srcTokenVaultAddress, TokenVault, opts.signer)

      return await srcTokenVaultContract.releaseERC20(opts.message, proof)
    }
  }
}
