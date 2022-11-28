import { BigNumber, Contract, Signer } from "ethers";
import type { Transaction } from "ethers";
import type { ApproveOpts, Bridge, BridgeOpts } from "../domain/bridge";
import TokenVault from "../constants/abi/TokenVault";
import ERC20 from "../constants/abi/ERC20";

class ERC20Bridge implements Bridge {
  private async spenderRequiresAllowance(
    tokenAddress: string,
    signer: Signer,
    amount: BigNumber,
    bridgeAddress: string
  ): Promise<boolean> {
    const contract: Contract = new Contract(tokenAddress, ERC20, signer);
    const allowance: BigNumber = await contract.allowance(
      await signer.getAddress(),
      bridgeAddress
    );

    return allowance.lt(amount);
  }

  async RequiresAllowance(opts: BridgeOpts): Promise<boolean> {
    return await this.spenderRequiresAllowance(
      opts.tokenAddress,
      opts.signer,
      opts.amountInWei,
      opts.bridgeAddress
    );
  }

  async Approve(opts: ApproveOpts): Promise<Transaction> {
    if (
      await this.spenderRequiresAllowance(
        opts.contractAddress,
        opts.signer,
        opts.amountInWei,
        opts.spenderAddress
      )
    ) {
      throw Error("token vault does not have required allowance");
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
}

export default ERC20Bridge;
