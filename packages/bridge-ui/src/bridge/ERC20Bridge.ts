import { BigNumber, Contract, ethers, Signer } from 'ethers';
import type { Transaction } from 'ethers';
import type {
  ApproveOpts,
  Bridge,
  BridgeOpts,
  ClaimOpts,
  ReleaseOpts,
} from '../domain/bridge';
import { tokenVaultABI, erc20ABI, bridgeABI } from '../constants/abi';
import type { Prover } from '../domain/proof';
import { MessageStatus } from '../domain/message';
import { chains } from '../chain/chains';
import { getLogger } from '../utils/logger';

const log = getLogger('ERC20Bridge');

export class ERC20Bridge implements Bridge {
  private readonly prover: Prover;

  constructor(prover: Prover) {
    this.prover = prover;
  }

  static async prepareTransaction(opts: BridgeOpts) {
    const contract: Contract = new Contract(
      opts.tokenVaultAddress,
      tokenVaultABI,
      opts.signer,
    );

    const owner = await opts.signer.getAddress();
    const message = {
      sender: owner,
      srcChainId: opts.fromChainId,
      destChainId: opts.toChainId,
      owner: owner,
      to: opts.to,
      refundAddress: owner,
      depositValue: opts.amountInWei,
      callValue: 0,
      processingFee: opts.processingFeeInWei ?? BigNumber.from(0),
      gasLimit: opts.processingFeeInWei
        ? BigNumber.from(140000)
        : BigNumber.from(0),
      memo: opts.memo ?? '',
    };

    if (!opts.isBridgedTokenAlreadyDeployed) {
      message.gasLimit = message.gasLimit.add(BigNumber.from(3000000));
    }

    log('Preparing transaction with message:', message);

    return { contract, owner, message };
  }

  private async spenderRequiresAllowance(
    tokenAddress: string,
    signer: Signer,
    amount: BigNumber,
    bridgeAddress: string,
  ): Promise<boolean> {
    const contract: Contract = new Contract(tokenAddress, erc20ABI, signer);
    const owner = await signer.getAddress();
    const allowance: BigNumber = await contract.allowance(owner, bridgeAddress);

    return allowance.lt(amount);
  }

  async RequiresAllowance(opts: ApproveOpts): Promise<boolean> {
    return await this.spenderRequiresAllowance(
      opts.contractAddress,
      opts.signer,
      opts.amountInWei,
      opts.spenderAddress,
    );
  }

  async Approve(opts: ApproveOpts): Promise<Transaction> {
    if (
      !(await this.spenderRequiresAllowance(
        opts.contractAddress,
        opts.signer,
        opts.amountInWei,
        opts.spenderAddress,
      ))
    ) {
      throw Error('token vault already has required allowance');
    }

    const contract: Contract = new Contract(
      opts.contractAddress,
      erc20ABI,
      opts.signer,
    );

    const tx = await contract.approve(opts.spenderAddress, opts.amountInWei);
    return tx;
  }

  async Bridge(opts: BridgeOpts): Promise<Transaction> {
    if (
      await this.spenderRequiresAllowance(
        opts.tokenAddress,
        opts.signer,
        opts.amountInWei,
        opts.tokenVaultAddress,
      )
    ) {
      throw Error('token vault does not have required allowance');
    }

    const { contract, message } = await ERC20Bridge.prepareTransaction(opts);

    log('Bridging with message', message);

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
    );

    log('Send ERC20 with transaction', tx);

    return tx;
  }

  async EstimateGas(opts: BridgeOpts): Promise<BigNumber> {
    const { contract, message } = await ERC20Bridge.prepareTransaction(opts);

    log('Estimating gas for sendERC20 with message', message);

    let gasEstimate = BigNumber.from(0);

    try {
      gasEstimate = await contract.estimateGas.sendERC20(
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
      );

      log('Estimated gas for sendERC20', gasEstimate);
    } catch (error) {
      console.error(error);
      if (error.code === ethers.errors.UNPREDICTABLE_GAS_LIMIT) {
        gasEstimate = BigNumber.from(1e6); // TODO: better estimate?
      }
    }

    return gasEstimate;
  }

  async Claim(opts: ClaimOpts): Promise<Transaction> {
    const contract: Contract = new Contract(
      opts.destBridgeAddress,
      bridgeABI,
      opts.signer,
    );

    const messageStatus: MessageStatus = await contract.getMessageStatus(
      opts.msgHash,
    );

    if (
      messageStatus === MessageStatus.Done ||
      messageStatus === MessageStatus.Failed
    ) {
      // TODO: should be throw a different error when status is Failed?
      throw Error('message already processed');
    }

    const signerAddress = await opts.signer.getAddress();

    if (opts.message.owner.toLowerCase() !== signerAddress.toLowerCase()) {
      throw Error('user can not process this, it is not their message');
    }

    if (messageStatus === MessageStatus.New) {
      const proof = await this.prover.generateProof({
        srcChain: opts.message.srcChainId,
        msgHash: opts.msgHash,
        sender: opts.srcBridgeAddress,
        srcBridgeAddress: opts.srcBridgeAddress,
        destChain: opts.message.destChainId,
        destCrossChainSyncAddress:
          chains[opts.message.destChainId].crossChainSyncAddress,
        srcSignalServiceAddress:
          chains[opts.message.srcChainId].signalServiceAddress,
      });

      if (opts.message.gasLimit.gt(BigNumber.from(2500000))) {
        return await contract.processMessage(opts.message, proof, {
          gasLimit: opts.message.gasLimit,
        });
      }

      let processMessageTx;
      try {
        processMessageTx = await contract.processMessage(opts.message, proof);
      } catch (error) {
        if (error.code === ethers.errors.UNPREDICTABLE_GAS_LIMIT) {
          processMessageTx = await contract.processMessage(
            opts.message,
            proof,
            {
              gasLimit: 1e6,
            },
          );
        } else {
          throw new Error(error);
        }
      }
      return processMessageTx;
    } else {
      return await contract.retryMessage(opts.message, false);
    }
  }

  async ReleaseTokens(opts: ReleaseOpts): Promise<Transaction> {
    const destBridgeContract: Contract = new Contract(
      opts.destBridgeAddress,
      bridgeABI,
      opts.destProvider,
    );

    const messageStatus: MessageStatus =
      await destBridgeContract.getMessageStatus(opts.msgHash);

    if (messageStatus === MessageStatus.Done) {
      throw Error('message already processed');
    }

    const signerAddress = await opts.signer.getAddress();

    if (opts.message.owner.toLowerCase() !== signerAddress.toLowerCase()) {
      throw Error('user can not release these tokens, it is not their message');
    }

    if (messageStatus === MessageStatus.Failed) {
      const proofOpts = {
        srcChain: opts.message.srcChainId,
        msgHash: opts.msgHash,
        sender: opts.srcBridgeAddress,
        destBridgeAddress: opts.destBridgeAddress,
        destChain: opts.message.destChainId,
        destCrossChainSyncAddress:
          chains[opts.message.destChainId].crossChainSyncAddress,
        srcCrossChainSyncAddress:
          chains[opts.message.srcChainId].crossChainSyncAddress,
      };

      const proof = await this.prover.generateReleaseProof(proofOpts);

      const srcTokenVaultContract: Contract = new Contract(
        opts.srcTokenVaultAddress,
        tokenVaultABI,
        opts.signer,
      );

      return await srcTokenVaultContract.releaseERC20(opts.message, proof);
    }
  }
}
