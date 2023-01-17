import { BigNumber, Contract, Signer } from "ethers";
import type { Transaction } from "ethers";
import type {
  ApproveOpts,
  Bridge,
  BridgeOpts,
  ClaimOpts,
} from "../domain/bridge";
import TokenVault from "../constants/abi/TokenVault";
import ERC20 from "../constants/abi/ERC20";
import type { Prover } from "../domain/proof";
import { MessageStatus } from "../domain/message";
import BridgeABI from "../constants/abi/Bridge";
import { chains } from "../domain/chain";

class ERC20Bridge implements Bridge {
  private readonly prover: Prover;

  constructor(prover: Prover) {
    this.prover = prover;
  }

  static async prepareTransaction(opts: BridgeOpts) {
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

  private async spenderRequiresAllowance(
    tokenAddress: string,
    signer: Signer,
    amount: BigNumber,
    bridgeAddress: string
  ): Promise<boolean> {
    const contract: Contract = new Contract(tokenAddress, ERC20, signer);
    const owner = await signer.getAddress();
    const allowance: BigNumber = await contract.allowance(owner, bridgeAddress);

    return allowance.lt(amount);
  }

  async RequiresAllowance(opts: ApproveOpts): Promise<boolean> {
    return await this.spenderRequiresAllowance(
      opts.contractAddress,
      opts.signer,
      opts.amountInWei,
      opts.spenderAddress
    );
  }

  async Approve(opts: ApproveOpts): Promise<Transaction> {
    if (
      !(await this.spenderRequiresAllowance(
        opts.contractAddress,
        opts.signer,
        opts.amountInWei,
        opts.spenderAddress
      ))
    ) {
      throw Error("token vault already has required allowance");
    }

    const contract: Contract = new Contract(
      opts.contractAddress,
      ERC20,
      opts.signer
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
        opts.tokenVaultAddress
      )
    ) {
      throw Error("token vault does not have required allowance");
    }

    const { contract, owner, message } = await ERC20Bridge.prepareTransaction(
      opts
    );

    const tx = await contract.sendERC20(
      message.destChainId,
      owner,
      opts.tokenAddress,
      opts.amountInWei,
      message.gasLimit,
      message.processingFee,
      message.refundAddress,
      message.memo,
      {
        value: message.processingFee.add(message.callValue),
      }
    );

    return tx;
  }

  async EstimateGas(opts: BridgeOpts): Promise<BigNumber> {
    const { contract, owner, message } = await ERC20Bridge.prepareTransaction(
      opts
    );

    const gasEstimate = await contract.estimateGas.sendERC20(
      message.destChainId,
      owner,
      opts.tokenAddress,
      opts.amountInWei,
      message.gasLimit,
      message.processingFee,
      message.refundAddress,
      message.memo,
      {
        value: message.processingFee.add(message.callValue),
      }
    );

    return gasEstimate;
  }

  async Claim(opts: ClaimOpts): Promise<Transaction> {
    const contract: Contract = new Contract(
      opts.destBridgeAddress,
      BridgeABI,
      opts.signer
    );

    const messageStatus: MessageStatus = await contract.getMessageStatus(
      opts.signal
    );

    if (
      messageStatus === MessageStatus.Done ||
      messageStatus === MessageStatus.Failed
    ) {
      throw Error("message already processed");
    }

    const signerAddress = await opts.signer.getAddress();

    if (opts.message.owner.toLowerCase() !== signerAddress.toLowerCase()) {
      throw Error("user can not process this, it is not their message");
    }

    if (messageStatus === MessageStatus.New) {
      const proof = await this.prover.GenerateProof({
        srcChain: opts.message.srcChainId.toNumber(),
        signal: opts.signal,
        sender: opts.srcBridgeAddress,
        srcBridgeAddress: opts.srcBridgeAddress,
        destChain: opts.message.destChainId.toNumber(),
        destHeaderSyncAddress:
          chains[opts.message.destChainId.toNumber()].headerSyncAddress,
      });

      return await contract.processMessage(opts.message, proof);
    } else {
      return await contract.retryMessage(opts.message, false);
    }
  }
}

export default ERC20Bridge;
