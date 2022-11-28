import { BigNumber, Contract } from "ethers";
import type { Transaction } from "ethers";
import type { ApproveOpts, Bridge, BridgeOpts } from "../domain/bridge";
import TokenVault from "../constants/abi/TokenVault";

class ETHBridge implements Bridge {
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
      sender: opts.signer.getAddress(),
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
}

export default ETHBridge;
