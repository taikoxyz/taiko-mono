import { BigNumber, Contract } from 'ethers';
import type { Transaction } from 'ethers';
import type {
  ApproveOpts,
  Bridge,
  BridgeOpts,
  ClaimOpts,
  ReleaseOpts,
} from '../domain/bridge';
import TokenVault from '../constants/abi/TokenVault';
import type { Prover } from '../domain/proof';
import { MessageStatus } from '../domain/message';
import BridgeABI from '../constants/abi/Bridge';
import { chainsRecord } from '../chain/chains';

export class ETHBridge implements Bridge {
  private readonly prover: Prover;

  constructor(prover: Prover) {
    this.prover = prover;
  }

  static async prepareTransaction(
    opts: BridgeOpts,
  ): Promise<{ contract: Contract; message: any; owner: string }> {
    const contract: Contract = new Contract(
      opts.tokenVaultAddress,
      TokenVault,
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

    const tx = await contract.sendEther(
      message.destChainId,
      message.to,
      message.gasLimit,
      message.processingFee,
      message.refundAddress,
      message.memo,
      {
        value: message.depositValue
          .add(message.processingFee)
          .add(message.callValue),
      },
    );

    return tx;
  }

  async EstimateGas(opts: BridgeOpts): Promise<BigNumber> {
    const { contract, message } = await ETHBridge.prepareTransaction(opts);

    const gasEstimate = await contract.estimateGas.sendEther(
      message.destChainId,
      message.to,
      message.gasLimit,
      message.processingFee,
      message.refundAddress,
      message.memo,
      {
        value: message.depositValue
          .add(message.processingFee)
          .add(message.callValue),
      },
    );

    return gasEstimate;
  }

  async Claim(opts: ClaimOpts): Promise<Transaction> {
    const contract: Contract = new Contract(
      opts.destBridgeAddress,
      BridgeABI,
      opts.signer,
    );

    const messageStatus: MessageStatus = await contract.getMessageStatus(
      opts.msgHash,
    );

    if (messageStatus === MessageStatus.Done) {
      throw Error('message already processed');
    }

    const signerAddress = await opts.signer.getAddress();

    if (opts.message.owner.toLowerCase() !== signerAddress.toLowerCase()) {
      throw Error('user can not process this, it is not their message');
    }

    if (messageStatus === MessageStatus.New) {
      const proofOpts = {
        srcChain: opts.message.srcChainId.toNumber(),
        msgHash: opts.msgHash,
        sender: opts.srcBridgeAddress,
        srcBridgeAddress: opts.srcBridgeAddress,
        destChain: opts.message.destChainId.toNumber(),
        destHeaderSyncAddress:
          chainsRecord[opts.message.destChainId.toNumber()].headerSyncAddress,
        srcSignalServiceAddress:
          chainsRecord[opts.message.srcChainId.toNumber()].signalServiceAddress,
      };

      const proof = await this.prover.GenerateProof(proofOpts);
      console.log(opts.message);
      return await contract.processMessage(opts.message, proof);
    } else {
      return await contract.retryMessage(opts.message, true);
    }
  }

  async ReleaseTokens(opts: ReleaseOpts): Promise<Transaction> {
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
        srcChain: opts.message.srcChainId.toNumber(),
        msgHash: opts.msgHash,
        sender: opts.srcBridgeAddress,
        destBridgeAddress: opts.destBridgeAddress,
        destChain: opts.message.destChainId.toNumber(),
        destHeaderSyncAddress:
          chainsRecord[opts.message.destChainId.toNumber()].headerSyncAddress,
        srcHeaderSyncAddress:
          chainsRecord[opts.message.srcChainId.toNumber()].headerSyncAddress,
      };

      const proof = await this.prover.GenerateReleaseProof(proofOpts);

      const srcBridgeContract: Contract = new Contract(
        opts.srcBridgeAddress,
        BridgeABI,
        opts.signer,
      );

      return await srcBridgeContract.releaseEther(opts.message, proof);
    }
  }
}
