import { BigNumber, Contract, ethers, Signer } from 'ethers';
import type { Transaction } from 'ethers';
import type {
  ApproveOpts,
  Bridge,
  BridgeOpts,
  ClaimOpts,
  ReleaseOpts,
} from '../domain/bridge';
import TokenVaultABI from '../constants/abi/TokenVault';
import ERC20_ABI from '../constants/abi/ERC20';
import type { Prover } from '../domain/proof';
import { Message, MessageStatus } from '../domain/message';
import BridgeABI from '../constants/abi/Bridge';
import { chains } from '../chain/chains';

export class ERC20Bridge implements Bridge {
  private readonly prover: Prover;

  constructor(prover: Prover) {
    this.prover = prover;
  }

  static async prepareTransaction(opts: BridgeOpts) {
    const tokenVaultContract: Contract = new Contract(
      opts.tokenVaultAddress,
      TokenVaultABI,
      opts.signer,
    );

    const owner = await opts.signer.getAddress();

    const message: Partial<Message> = {
      sender: owner,
      srcChainId: opts.fromChainId,
      destChainId: opts.toChainId,
      owner: owner,
      to: opts.to,
      refundAddress: owner,
      depositValue: opts.amountInWei,
      callValue: BigNumber.from(0),
      processingFee: opts.processingFeeInWei ?? BigNumber.from(0),
      gasLimit: opts.processingFeeInWei
        ? BigNumber.from(140000)
        : BigNumber.from(0),
      memo: opts.memo ?? '',
    };

    if (!opts.isBridgedTokenAlreadyDeployed) {
      message.gasLimit = message.gasLimit.add(BigNumber.from(3000000));
    }

    return { tokenVaultContract, owner, message };
  }

  private async spenderRequiresAllowance(
    tokenAddress: string,
    signer: Signer,
    amount: BigNumber,
    bridgeAddress: string,
  ): Promise<boolean> {
    const erc20Contract = new Contract(tokenAddress, ERC20_ABI, signer);

    const owner = await signer.getAddress();

    const allowance: BigNumber = await erc20Contract.allowance(
      owner,
      bridgeAddress,
    );

    return allowance.lt(amount);
  }

  requiresAllowance(opts: ApproveOpts): Promise<boolean> {
    return this.spenderRequiresAllowance(
      opts.contractAddress,
      opts.signer,
      opts.amountInWei,
      opts.spenderAddress,
    );
  }

  async approve(opts: ApproveOpts): Promise<Transaction> {
    const requiresAllowance = await this.spenderRequiresAllowance(
      opts.contractAddress,
      opts.signer,
      opts.amountInWei,
      opts.spenderAddress,
    );

    if (!requiresAllowance) {
      // TODO: how about error codes instead? will be better for i18n
      //       and also to better handle errors in the UI by comparing
      //       error codes instead of error messages.
      throw Error('token vault already has required allowance');
    }

    const erc20Contract: Contract = new Contract(
      opts.contractAddress,
      ERC20_ABI,
      opts.signer,
    );

    const tx = await erc20Contract.approve(
      opts.spenderAddress,
      opts.amountInWei,
    );

    return tx;
  }

  async bridge(opts: BridgeOpts): Promise<Transaction> {
    const requiresAllowance = await this.spenderRequiresAllowance(
      opts.tokenAddress,
      opts.signer,
      opts.amountInWei,
      opts.tokenVaultAddress,
    );

    if (requiresAllowance) {
      throw Error('token vault does not have required allowance');
    }

    const { tokenVaultContract, message } =
      await ERC20Bridge.prepareTransaction(opts);

    const tx = await tokenVaultContract.sendERC20(
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

    return tx;
  }

  async estimateGas(opts: BridgeOpts): Promise<BigNumber> {
    const { tokenVaultContract, message } =
      await ERC20Bridge.prepareTransaction(opts);

    const gasEstimate = await tokenVaultContract.estimateGas.sendERC20(
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

    return gasEstimate;
  }

  async claim(opts: ClaimOpts): Promise<Transaction> {
    const destBridgeContract = new Contract(
      opts.destBridgeAddress,
      BridgeABI,
      opts.signer,
    );

    const messageStatus: MessageStatus =
      await destBridgeContract.getMessageStatus(opts.msgHash);

    const isMessageProcessed = [
      MessageStatus.Done,
      MessageStatus.Failed,
    ].includes(messageStatus);

    if (isMessageProcessed) {
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
        destHeaderSyncAddress:
          chains[opts.message.destChainId].headerSyncAddress,
        srcSignalServiceAddress:
          chains[opts.message.srcChainId].signalServiceAddress,
      });

      if (opts.message.gasLimit.gt(BigNumber.from(2500000))) {
        return destBridgeContract.processMessage(opts.message, proof, {
          gasLimit: opts.message.gasLimit,
        });
      }

      let processMessageTx: Transaction;

      try {
        processMessageTx = await destBridgeContract.processMessage(
          opts.message,
          proof,
        );
      } catch (error) {
        if (error.code === ethers.errors.UNPREDICTABLE_GAS_LIMIT) {
          processMessageTx = await destBridgeContract.processMessage(
            opts.message,
            proof,
            {
              gasLimit: 1e6,
            },
          );
        } else {
          throw Error(error);
        }
      }
      return processMessageTx;
    } else {
      return destBridgeContract.retryMessage(opts.message, false);
    }
  }

  async releaseToken(opts: ReleaseOpts): Promise<Transaction> {
    const destBridgeContract: Contract = new Contract(
      opts.destBridgeAddress,
      BridgeABI,
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
        destHeaderSyncAddress:
          chains[opts.message.destChainId].headerSyncAddress,
        srcHeaderSyncAddress: chains[opts.message.srcChainId].headerSyncAddress,
      };

      const proof = await this.prover.generateReleaseProof(proofOpts);

      const srcTokenVaultContract: Contract = new Contract(
        opts.srcTokenVaultAddress,
        TokenVaultABI,
        opts.signer,
      );

      return srcTokenVaultContract.releaseERC20(opts.message, proof);
    }
  }
}
