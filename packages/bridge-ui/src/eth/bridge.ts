import { BigNumber, Contract } from "ethers";
import type { Transaction } from "ethers";
import type {
  ApproveOpts,
  Bridge as BridgeInterface,
  BridgeOpts,
  ClaimOpts,
} from "../domain/bridge";
import TokenVault from "../constants/abi/TokenVault";
import type { Prover } from "../domain/proof";
import { MessageStatus } from "../domain/message";
import Bridge from "../constants/abi/Bridge";
import { chains } from "../domain/chain";

class ETHBridge implements BridgeInterface {
  private readonly prover: Prover;

  constructor(prover: Prover) {
    this.prover = prover;
  }

  static async prepareTransaction(
    opts: BridgeOpts
  ): Promise<{ contract: Contract; message: any; owner: string }> {
    const contract: Contract = new Contract(
      opts.tokenVaultAddress,
      TokenVault,
      opts.signer
    );

    const owner = await opts.signer.getAddress();
    const message = {
      sender: owner,
      srcChainId: opts.fromChainId,
      destChainId: opts.toChainId,
      owner: owner,
      to: owner,
      refundAddress: owner,
      depositValue: opts.amountInWei,
      callValue: 0,
      processingFee: opts.processingFeeInWei ?? BigNumber.from(0),
      gasLimit: opts.processingFeeInWei
        ? BigNumber.from(140000)
        : BigNumber.from(0),
      memo: opts.memo ?? "",
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
    const { contract, owner, message } = await ETHBridge.prepareTransaction(
      opts
    );

    const tx = await contract.sendEther(
      message.destChainId,
      owner,
      message.gasLimit,
      message.processingFee,
      message.refundAddress,
      message.memo,
      {
        value: message.depositValue
          .add(message.processingFee)
          .add(message.callValue),
      }
    );

    return tx;
  }

  async EstimateGas(opts: BridgeOpts): Promise<BigNumber> {
    const { contract, owner, message } = await ETHBridge.prepareTransaction(
      opts
    );

    const gasEstimate = await contract.estimateGas.sendEther(
      message.destChainId,
      owner,
      message.gasLimit,
      message.processingFee,
      message.refundAddress,
      message.memo,
      {
        value: message.depositValue
          .add(message.processingFee)
          .add(message.callValue),
      }
    );

    return gasEstimate;
  }

  async Claim(opts: ClaimOpts): Promise<Transaction> {
    const contract: Contract = new Contract(
      opts.destBridgeAddress,
      Bridge,
      opts.signer
    );

    const messageStatus: MessageStatus = await contract.getMessageStatus(
      opts.signal
    );

    if (messageStatus === MessageStatus.Done) {
      throw Error("message already processed");
    }

    const signerAddress = await opts.signer.getAddress();

    if (opts.message.owner.toLowerCase() !== signerAddress.toLowerCase()) {
      throw Error("user can not process this, it is not their message");
    }

    if (messageStatus === MessageStatus.New) {
      const proofOpts = {
        srcChain: opts.message.srcChainId.toNumber(),
        signal: opts.signal,
        sender: opts.srcBridgeAddress,
        srcBridgeAddress: opts.srcBridgeAddress,
        destChain: opts.message.destChainId.toNumber(),
        destHeaderSyncAddress:
          chains[opts.message.destChainId.toNumber()].headerSyncAddress,
      };

      const proof = await this.prover.GenerateProof(proofOpts);

      return await contract.processMessage(opts.message, proof);
    } else {
      return await contract.retryMessage(opts.message);
    }
  }
}

export default ETHBridge;
