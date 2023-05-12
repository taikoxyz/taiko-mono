import { BigNumber, Contract, ethers } from 'ethers';
import type { Transaction } from 'ethers';
import type {
  ApproveOpts,
  Bridge,
  BridgeOpts,
  ClaimOpts,
  ReleaseOpts,
} from '../domain/bridge';
import type { Prover } from '../domain/proof';
import { bridgeABI } from '../constants/abi';
import { chains } from '../chain/chains';
import { type Message, MessageStatus } from '../domain/message';
import { getLogger } from '../utils/logger';

const log = getLogger('ETHBridge');

export class ETHBridge implements Bridge {
  private readonly prover: Prover;

  constructor(prover: Prover) {
    this.prover = prover;
  }

  static async prepareTransaction(
    opts: BridgeOpts,
  ): Promise<{ contract: Contract; message: Message; owner: string }> {
    const contract: Contract = new Contract(
      opts.bridgeAddress,
      bridgeABI,
      opts.signer,
    );

    const owner = await opts.signer.getAddress();
    const message: Message = {
      sender: owner,
      srcChainId: opts.fromChainId,
      destChainId: opts.toChainId,
      owner: owner,
      to: opts.to,
      refundAddress: owner,
      depositValue:
        opts.to.toLowerCase() === owner.toLowerCase()
          ? opts.amountInWei
          : BigNumber.from(0),
      callValue:
        opts.to.toLowerCase() === owner.toLowerCase()
          ? BigNumber.from(0)
          : opts.amountInWei,
      processingFee: opts.processingFeeInWei ?? BigNumber.from(0),
      gasLimit: opts.processingFeeInWei
        ? BigNumber.from(140000)
        : BigNumber.from(0),
      memo: opts.memo ?? '',
      id: 1, // will be set in contract,
      data: '0x',
    };

    log('Preparing transaction with message', message);

    return { contract, owner, message };
  }

  RequiresAllowance(opts: ApproveOpts): Promise<boolean> {
    return Promise.resolve(false);
  }

  // ETH does not need to be approved for transacting
  Approve(opts: ApproveOpts): Promise<Transaction> {
    return new Promise((resolve) => resolve({} as unknown as Transaction));
  }

  async Bridge(opts: BridgeOpts): Promise<Transaction> {
    const { contract, message } = await ETHBridge.prepareTransaction(opts);

    const value = message.depositValue
      .add(message.processingFee)
      .add(message.callValue);

    log('Sending message to bridge with value', value.toString());

    try {
      const tx = await contract.sendMessage(message, { value });

      log('Message sent with transaction', tx);

      return tx;
    } catch (error) {
      console.error(error);
      throw new Error('failed to send message to bridge', { cause: error });
    }
  }

  async EstimateGas(opts: BridgeOpts): Promise<BigNumber> {
    const { contract, message } = await ETHBridge.prepareTransaction(opts);

    const value = message.depositValue
      .add(message.processingFee)
      .add(message.callValue);

    log('Estimating gas for sendMessage. Value to send', value.toString());

    try {
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

  async Claim(opts: ClaimOpts): Promise<Transaction> {
    const contract: Contract = new Contract(
      opts.destBridgeAddress,
      bridgeABI,
      opts.signer,
    );

    const messageStatus: MessageStatus = await contract.getMessageStatus(
      opts.msgHash,
    );

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

      let processMessageTx: ethers.Transaction;

      try {
        processMessageTx = await contract.processMessage(opts.message, proof);
      } catch (error) {
        console.error(error);

        if (error.code === ethers.errors.UNPREDICTABLE_GAS_LIMIT) {
          const gasLimit = 1e6;

          log(`Unpredictable gas limit. We try now with ${gasLimit} gasLimit`);

          processMessageTx = await contract.processMessage(
            opts.message,
            proof,
            { gasLimit },
          );
        } else {
          throw new Error('failed to process message', { cause: error });
        }
      }

      log('Message processed with transaction', processMessageTx);

      return processMessageTx;
    } else {
      log('Retrying message', opts.message);
      const tx = await contract.retryMessage(opts.message, true);
      log('Message retried with transaction', tx);

      return tx;
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

      const srcBridgeContract: Contract = new Contract(
        opts.srcBridgeAddress,
        bridgeABI,
        opts.signer,
      );

      return await srcBridgeContract.releaseEther(opts.message, proof);
    }
  }
}
