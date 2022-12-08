import { BigNumber, Contract } from "ethers";
import type { Transaction } from "ethers";
import type {
  ApproveOpts,
  Bridge,
  BridgeOpts,
  ClaimOpts,
} from "../domain/bridge";
import TokenVault from "../constants/abi/TokenVault";
import type { Prover } from "../domain/proof";
import { MessageStatus } from "../domain/message";

class ETHBridge implements Bridge {
  private readonly prover: Prover;

  constructor(prover: Prover) {
    this.prover = prover;
  }

  RequiresAllowance(opts: ApproveOpts): Promise<boolean> {
    return Promise.resolve(false);
  }

  // ETH does not need to be approved for transacting
  Approve(opts: ApproveOpts): Promise<Transaction> {
    return new Promise((resolve) => resolve({} as unknown as Transaction));
  }

  async Bridge(opts: BridgeOpts): Promise<Transaction> {
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
      throw Error("user can not process this, it is not their message");
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

export default ETHBridge;
