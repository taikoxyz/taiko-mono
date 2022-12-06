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

class ERC20Bridge implements Bridge {
  private readonly prover: Prover;

  constructor(prover: Prover) {
    this.prover = prover;
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
        opts.bridgeAddress
      )
    ) {
      throw Error("token vault does not have required allowance");
    }

    const contract: Contract = new Contract(
      opts.bridgeAddress,
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
        ? BigNumber.from(100000)
        : BigNumber.from(0),
      memo: opts.memo ?? "",
    };

    const tx = await contract.sendERC20(
      message.destChainId,
      owner,
      opts.tokenAddress,
      opts.amountInWei,
      message.gasLimit,
      message.processingFee,
      message.refundAddress,
      message.memo
    );

    return tx;
  }

  async Claim(opts: ClaimOpts): Promise<Transaction> {
    const contract: Contract = new Contract(
      opts.destBridgeAddress,
      TokenVault,
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
      throw Error("use can not process this, it is not their message");
    }

    if (messageStatus === MessageStatus.New) {
      const proof = await this.prover.GenerateProof({
        srcChain: opts.message.srcChainId,
        signal: opts.signal,
        sender: opts.message.sender,
        srcBridgeAddress: opts.srcBridgeAddress,
      });

      return await contract.processMessage(opts.message, proof);
    } else {
      return await contract.retryMessage(opts.message);
    }
  }
}

export default ERC20Bridge;
