import type { Transaction } from 'ethers';
import { BigNumber, Contract, ethers } from 'ethers';

import { chains } from '../chain/chains';
import { bridgeABI } from '../constants/abi';
import type {
  Bridge,
  BridgeOpts,
  ClaimOpts,
  ReleaseOpts,
} from '../domain/bridge';
import { type Message, MessageStatus } from '../domain/message';
import type { Prover } from '../domain/proof';
import { getLogger } from '../utils/logger';

const log = getLogger('ETHBridge');

export class ETHBridge implements Bridge {
  private readonly prover: Prover;

  constructor(prover: Prover) {
    this.prover = prover;
  }

  private static async _prepareTransaction(
    opts: BridgeOpts,
  ): Promise<{ contract: Contract; message: Message; owner: string }> {
    const contract = new Contract(opts.bridgeAddress, bridgeABI, opts.signer);

    const owner = await opts.signer.getAddress();

    const depositValue =
      opts.to.toLowerCase() === owner.toLowerCase()
        ? opts.amount
        : BigNumber.from(0);

    const callValue =
      opts.to.toLowerCase() === owner.toLowerCase()
        ? BigNumber.from(0)
        : opts.amount;

    const processingFee = opts.processingFeeInWei ?? BigNumber.from(0);

    const gasLimit = opts.processingFeeInWei
      ? BigNumber.from(140000) // TODO: 140k ??
      : BigNumber.from(0);

    const memo = opts.memo ?? '';

    const message: Message = {
      owner,
      sender: owner,
      refundAddress: owner,

      to: opts.to,
      srcChainId: opts.srcChainId,
      destChainId: opts.destChainId,

      gasLimit,
      callValue,
      depositValue,
      processingFee,

      memo,
      id: 1, // will be set in contract,
      data: '0x',
    };

    log('Preparing transaction with message', message);

    return { contract, owner, message };
  }

  requiresAllowance(): Promise<boolean> {
    return Promise.resolve(false);
  }

  // ETH does not need to be approved for transacting
  approve(): Promise<Transaction> {
    return new Promise((resolve) => resolve({} as Transaction));
  }

  async bridge(opts: BridgeOpts): Promise<Transaction> {
    const { contract, message } = await ETHBridge._prepareTransaction(opts);

    const value = message.depositValue
      .add(message.processingFee)
      .add(message.callValue);

    log('Sending message to bridge with value', value.toString());

    try {
      const tx = await contract.sendMessage(message, { value });

      log('Sending message with transaction', tx);

      return tx;
    } catch (error) {
      console.error(error);
      throw new Error('failed to send message to bridge', { cause: error });
    }
  }

  async estimateGas(opts: BridgeOpts): Promise<BigNumber> {
    const { contract, message } = await ETHBridge._prepareTransaction(opts);

    const value = message.depositValue
      .add(message.processingFee)
      .add(message.callValue);

    log(`Estimating gas for sendMessage. Value to send: ${value}`);

    try {
      // See https://docs.ethers.org/v5/api/contract/contract/#contract-estimateGas
      const gasEstimate = await contract.estimateGas.sendMessage(message, {
        value,
      });

      log('Estimated gas', gasEstimate.toString());

      return gasEstimate;
    } catch (error) {
      console.error(error);
      throw new Error('failed to estimate gas for sendMessage', {
        cause: error,
      });
    }
  }

  async claim(opts: ClaimOpts): Promise<Transaction> {
    const destBridgeContract: Contract = new Contract(
      opts.destBridgeAddress,
      bridgeABI,
      opts.signer,
    );

    const messageStatus: MessageStatus =
      await destBridgeContract.getMessageStatus(opts.msgHash);

    log(`Claiming message with status ${messageStatus}`);

    if (messageStatus === MessageStatus.Done) {
      throw Error('message already processed');
    }

    if (messageStatus === MessageStatus.Failed) {
      throw Error('user can not process this, message has failed');
    }

    const signerAddress = await opts.signer.getAddress();

    if (opts.message.owner.toLowerCase() !== signerAddress.toLowerCase()) {
      throw Error('user can not process this, it is not their message');
    }

    // TODO: up to here we share same logic as ERC20Bridge

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

      // log('Proof generated', proof);

      let processMessageTx: ethers.Transaction;

      try {
        processMessageTx = await destBridgeContract.processMessage(
          opts.message,
          proof,
        );
      } catch (error) {
        console.error(error);

        if (error.code === ethers.errors.UNPREDICTABLE_GAS_LIMIT) {
          // See https://docs.ethers.org/v5/troubleshooting/errors/#help-UNPREDICTABLE_GAS_LIMIT
          const gasLimit = 1e6; // TODO: magic number

          log(`Unpredictable gas limit. We try now with ${gasLimit} gasLimit`);

          processMessageTx = await destBridgeContract.processMessage(
            opts.message,
            proof,
            { gasLimit },
          );
        } else {
          throw new Error('failed to process message', { cause: error });
        }
      }

      log('Processing message with transaction', processMessageTx);

      return processMessageTx;
    } else {
      try {
        log('Retrying message', opts.message);

        const tx = await destBridgeContract.retryMessage(opts.message, true);

        log('Message retried with transaction', tx);

        return tx;
      } catch (error) {
        console.error(error);
        throw new Error('failed to retry message', { cause: error });
      }
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

      const srcBridgeContract: Contract = new Contract(
        opts.srcBridgeAddress,
        bridgeABI,
        opts.signer,
      );

      try {
        log('Releasing ether with message', opts.message);

        const tx: Transaction = await srcBridgeContract.releaseEther(
          opts.message,
          proof,
        );

        log('Released ether with transaction', tx);

        return tx;
      } catch (error) {
        console.error(error);
        throw new Error('failed to release ether', { cause: error });
      }
    }
  }
}
