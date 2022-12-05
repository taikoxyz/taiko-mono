import { BigNumber, Wallet } from "ethers";
import { mainnet, taiko } from "../domain/chain";
import type { Bridge, BridgeOpts } from "../domain/bridge";
import ETHBridge from "./bridge";

const mockSigner = {
  getAddress: jest.fn(),
};

const mockContract = {
  sendEther: jest.fn(),
};

jest.mock("ethers", () => ({
  /* eslint-disable-next-line */
  ...(jest.requireActual("ethers") as object),
  Wallet: function () {
    return mockSigner;
  },
  Signer: function () {
    return mockSigner;
  },
  Contract: function () {
    return mockContract;
  },
}));

describe("bridge tests", () => {
  beforeEach(() => {
    jest.resetAllMocks();
  });

  it("requires allowance returns false", async () => {
    const bridge: Bridge = new ETHBridge();
    const wallet = new Wallet("0x");

    const requires = await bridge.RequiresAllowance({
      amountInWei: BigNumber.from(1),
      signer: new Wallet("0x"),
      contractAddress: "0x1234",
      spenderAddress: "0x",
    });
    expect(requires).toBe(false);
  });

  it("approve returns empty transaction", async () => {
    const bridge: Bridge = new ETHBridge();

    const tx = await bridge.Approve({
      amountInWei: BigNumber.from(1),
      signer: new Wallet("0x"),
      contractAddress: "0x1234",
      spenderAddress: "0x",
    });
  });

  it("bridges with processing fee", async () => {
    const bridge: Bridge = new ETHBridge();
    const wallet = new Wallet("0x");

    const opts: BridgeOpts = {
      amountInWei: BigNumber.from(1),
      signer: wallet,
      tokenAddress: "",
      fromChainId: mainnet.id,
      toChainId: taiko.id,
      bridgeAddress: "0x456",
      processingFeeInWei: BigNumber.from(2),
      memo: "memo",
    };

    expect(mockSigner.getAddress).not.toHaveBeenCalled();
    await bridge.Bridge(opts);

    expect(mockSigner.getAddress).toHaveBeenCalled();
    expect(mockContract.sendEther).toHaveBeenCalledWith(
      opts.toChainId,
      wallet.getAddress(),
      BigNumber.from(100000),
      opts.processingFeeInWei,
      wallet.getAddress(),
      opts.memo,
      {
        value: opts.amountInWei.add(opts.processingFeeInWei),
      }
    );
  });

  it("bridges without processing fee", async () => {
    const bridge: Bridge = new ETHBridge();

    const wallet = new Wallet("0x");

    const opts: BridgeOpts = {
      amountInWei: BigNumber.from(1),
      signer: wallet,
      tokenAddress: "",
      fromChainId: mainnet.id,
      toChainId: taiko.id,
      bridgeAddress: "0x456",
    };

    await bridge.Bridge(opts);
    expect(mockContract.sendEther).toHaveBeenCalledWith(
      opts.toChainId,
      wallet.getAddress(),
      BigNumber.from(0),
      BigNumber.from(0),
      wallet.getAddress(),
      "",
      { value: opts.amountInWei }
    );
  });
});
