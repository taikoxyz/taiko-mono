import type { Transaction } from 'ethers';
import { BigNumber, Contract, ethers, Signer } from 'ethers';

import { chains } from '../chain/chains';
import { bridgeABI, erc20ABI, tokenVaultABI } from '../constants/abi';
import type {
  ApproveOpts,
  Bridge,
  BridgeOpts,
  ClaimOpts,
  ReleaseOpts,
} from '../domain/bridge';
import { MessageStatus } from '../domain/message';
import type { Prover } from '../domain/proof';
import { getLogger } from '../utils/logger';

const log = getLogger('ERC20Bridge');

export class ERC20Bridge implements Bridge {
  private readonly prover: Prover;

  constructor(prover: Prover) {
    this.prover = prover;
  }

  private static async _prepareTransaction(opts: BridgeOpts) {
    const contract = new Contract(
      opts.tokenVaultAddress,
      tokenVaultABI,
      opts.signer,
    );

    const processingFee = opts.processingFeeInWei ?? BigNumber.from(0);

    const gasLimit = opts.processingFeeInWei
      ? BigNumber.from(140000)
      : BigNumber.from(0);

    const memo = opts.memo ?? '';

    const owner = await opts.signer.getAddress();
    const message = {
      owner,
      sender: owner,
      refundAddress: owner,

      to: opts.to,
      srcChainId: opts.srcChainId,
      destChainId: opts.destChainId,

      depositValue: opts.amount,
      callValue: 0,
      processingFee,
      gasLimit,
      memo,
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
    const tokenContract: Contract = new Contract(
      tokenAddress,
      erc20ABI,
      signer,
    );

    const owner = await signer.getAddress();

    try {
      log(
        `Allowance of amount ${amount} tokens for spender "${bridgeAddress}"`,
      );

      const allowance: BigNumber = await tokenContract.allowance(
        owner,
        bridgeAddress,
      );

      const requiresAllowance = allowance.lt(amount);
      log(`Requires allowance? ${requiresAllowance}`);

      return requiresAllowance;
    } catch (error) {
      console.error(error);
      throw new Error(`there was an issue getting allowance`, {
        cause: error,
      });
    }
  }

  async requiresAllowance(opts: ApproveOpts): Promise<boolean> {
    return this.spenderRequiresAllowance(
      opts.contractAddress,
      opts.signer,
      opts.amount,
      opts.spenderAddress,
    );
  }

  async approve(opts: ApproveOpts): Promise<Transaction> {
    const requiresAllowance = await this.spenderRequiresAllowance(
      opts.contractAddress,
      opts.signer,
      opts.amount,
      opts.spenderAddress,
    );

    if (!requiresAllowance) {
      throw Error('token vault already has required allowance');
    }

    const contract: Contract = new Contract(
      opts.contractAddress,
      erc20ABI,
      opts.signer,
    );

    try {
      log(
        `Approving ${opts.amount} tokens for spender "${opts.spenderAddress}"`,
      );

      const tx = await contract.approve(opts.spenderAddress, opts.amount);

      log('Approval sent with transaction', tx);

      return tx;
    } catch (error) {
      console.error(error);
      throw new Error('encountered an issue while approving', {
        cause: error,
      });
    }
  }

  async bridge(opts: BridgeOpts): Promise<Transaction> {
    const requiresAllowance = await this.spenderRequiresAllowance(
      opts.tokenAddress,
      opts.signer,
      opts.amount,
      opts.tokenVaultAddress,
    );

    if (requiresAllowance) {
      throw Error('token vault does not have required allowance');
    }

    const { contract, message } = await ERC20Bridge._prepareTransaction(opts);

    const value = message.processingFee.add(message.callValue);

    log('Sending ERC20 to bridge with value', value.toString());

    try {
      const tx = await contract.sendERC20(
        message.destChainId,
        message.to,
        opts.tokenAddress,
        opts.amount,
        message.gasLimit,
        message.processingFee,
        message.refundAddress,
        message.memo,
        { value },
      );

      log('Sending ERC20 with transaction', tx);

      return tx;
    } catch (error) {
      console.error(error);
      throw new Error('something happened while bridging', {
        cause: error,
      });
    }
  }

  async estimateGas(opts: BridgeOpts): Promise<BigNumber> {
    const { contract, message } = await ERC20Bridge._prepareTransaction(opts);

    log('Estimating gas for sendERC20 with message', message);

    let gasEstimate = BigNumber.from(0);

    try {
      gasEstimate = await contract.estimateGas.sendERC20(
        message.destChainId,
        message.to,
        opts.tokenAddress,
        opts.amount,
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
      throw new Error('found a problem estimating gas', {
        cause: error,
      });
    }

    return gasEstimate;
  }

  async claim(opts: ClaimOpts): Promise<Transaction> {
    const contract: Contract = new Contract(
      opts.destBridgeAddress,
      bridgeABI,
      opts.signer,
    );

    const messageStatus: MessageStatus = await contract.getMessageStatus(
      opts.msgHash,
    );

    log(`Claiming message with status ${messageStatus}`);

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
      const proofOpts = {
        srcChain: opts.message.srcChainId,
        msgHash: opts.msgHash,
        sender: opts.srcBridgeAddress,
        srcBridgeAddress: opts.srcBridgeAddress,
        destChain: opts.message.destChainId,
        destCrossChainSyncAddress:
          chains[opts.message.destChainId].crossChainSyncAddress,
        srcSignalServiceAddress:
          chains[opts.message.srcChainId].signalServiceAddress,
      };

      log('Generating proof with opts', proofOpts);

      const proof = await this.prover.generateProof(proofOpts);

      let processMessageTx: ethers.Transaction;

      try {
        if (opts.message.gasLimit.gt(BigNumber.from(2500000))) {
          // TODO: 2.5M ??
          processMessageTx = await contract.processMessage(
            opts.message,
            proof,
            {
              gasLimit: opts.message.gasLimit,
            },
          );
        } else {
          processMessageTx = await contract.processMessage(opts.message, proof);
        }
      } catch (error) {
        console.error(error);

        if (error.code === ethers.errors.UNPREDICTABLE_GAS_LIMIT) {
          processMessageTx = await contract.processMessage(
            opts.message,
            proof,
            {
              gasLimit: 1e6,
            },
          );
        } else {
          throw new Error('failed to process message', { cause: error });
        }
      }

      log('Processing message with transaction', processMessageTx);

      return processMessageTx;
    } else {
      log('Retrying message', opts.message);
      const tx: Transaction = await contract.retryMessage(opts.message, false);
      log('Message retried with transaction', tx);

      return tx;
    }
  }

  async release(opts: ReleaseOpts): Promise<Transaction> {
    const destBridgeContract: Contract = new Contract(
      opts.destBridgeAddress,
      bridgeABI,
      opts.destProvider,
    );

    const messageStatus: MessageStatus =
      await destBridgeContract.getMessageStatus(opts.msgHash);

    log(`Releasing message with status ${messageStatus}`);

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

      log('Generating release proof with opts', proofOpts);

      const proof = await this.prover.generateReleaseProof(proofOpts);

      const srcTokenVaultContract: Contract = new Contract(
        opts.srcTokenVaultAddress,
        tokenVaultABI,
        opts.signer,
      );

      try {
        log('Releasing tokens with message', opts.message);

        const tx: Transaction = await srcTokenVaultContract.releaseERC20(
          opts.message,
          proof,
        );

        log('Realising tokens with transaction', tx);

        return tx;
      } catch (error) {
        console.error(error);
        throw new Error('failed to release tokens', { cause: error });
      }
    }
  }
}
