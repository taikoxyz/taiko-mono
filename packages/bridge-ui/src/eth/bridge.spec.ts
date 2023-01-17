import { BigNumber, Wallet } from "ethers";
import {
  CHAIN_ID_MAINNET,
  CHAIN_ID_TAIKO,
  mainnet,
  taiko,
} from "../domain/chain";
import type { Bridge, BridgeOpts } from "../domain/bridge";
import ETHBridge from "./bridge";
import { Message, MessageStatus } from "../domain/message";

const mockSigner = {
  getAddress: jest.fn(),
};

const mockContract = {
  sendEther: jest.fn(),
  getMessageStatus: jest.fn(),
  processMessage: jest.fn(),
  retryMessage: jest.fn(),
};

const mockProver = {
  GenerateProof: jest.fn(),
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
    const bridge: Bridge = new ETHBridge(null);

    const requires = await bridge.RequiresAllowance({
      amountInWei: BigNumber.from(1),
      signer: new Wallet("0x"),
      contractAddress: "0x1234",
      spenderAddress: "0x",
    });
    expect(requires).toBe(false);
  });

  it("approve returns empty transaction", async () => {
    const bridge: Bridge = new ETHBridge(null);

    const tx = await bridge.Approve({
      amountInWei: BigNumber.from(1),
      signer: new Wallet("0x"),
      contractAddress: "0x1234",
      spenderAddress: "0x",
    });
  });

  it("bridges with processing fee", async () => {
    const bridge: Bridge = new ETHBridge(null);
    const wallet = new Wallet("0x");

    const opts: BridgeOpts = {
      amountInWei: BigNumber.from(1),
      signer: wallet,
      tokenAddress: "",
      fromChainId: mainnet.id,
      toChainId: taiko.id,
      tokenVaultAddress: "0x456",
      processingFeeInWei: BigNumber.from(2),
      memo: "memo",
    };

    expect(mockSigner.getAddress).not.toHaveBeenCalled();
    await bridge.Bridge(opts);

    expect(mockSigner.getAddress).toHaveBeenCalled();
    expect(mockContract.sendEther).toHaveBeenCalledWith(
      opts.toChainId,
      wallet.getAddress(),
      BigNumber.from(140000),
      opts.processingFeeInWei,
      wallet.getAddress(),
      "memo",
      {
        value: BigNumber.from(3),
      }
    );
  });

  it("bridges without processing fee", async () => {
    const bridge: Bridge = new ETHBridge(null);

    const wallet = new Wallet("0x");

    const opts: BridgeOpts = {
      amountInWei: BigNumber.from(1),
      signer: wallet,
      tokenAddress: "",
      fromChainId: mainnet.id,
      toChainId: taiko.id,
      tokenVaultAddress: "0x456",
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

  it("claim throws if message status is done", async () => {
    mockContract.getMessageStatus.mockImplementationOnce(() => {
      return MessageStatus.Done;
    });

    const wallet = new Wallet("0x");

    const bridge: Bridge = new ETHBridge(null);

    await expect(
      bridge.Claim({
        message: {
          srcChainId: BigNumber.from(CHAIN_ID_TAIKO),
          destChainId: BigNumber.from(CHAIN_ID_MAINNET),
          gasLimit: BigNumber.from(1),
        } as unknown as Message,
        signal: "0x",
        srcBridgeAddress: "0x",
        destBridgeAddress: "0x",
        signer: wallet,
      })
    ).rejects.toThrowError("message already processed");
  });

  it("claim throws if message owner is not signer", async () => {
    mockContract.getMessageStatus.mockImplementationOnce(() => {
      return MessageStatus.New;
    });

    mockSigner.getAddress.mockImplementationOnce(() => {
      return "0xfake";
    });

    const wallet = new Wallet("0x");

    const bridge: Bridge = new ETHBridge(null);

    await expect(
      bridge.Claim({
        message: {
          owner: "0x",
          srcChainId: BigNumber.from(CHAIN_ID_TAIKO),
          destChainId: BigNumber.from(CHAIN_ID_MAINNET),
          gasLimit: BigNumber.from(1),
        } as unknown as Message,
        signal: "0x",
        srcBridgeAddress: "0x",
        destBridgeAddress: "0x",
        signer: wallet,
      })
    ).rejects.toThrowError(
      "user can not process this, it is not their message"
    );
  });

  it("claim processMessage", async () => {
    mockContract.getMessageStatus.mockImplementationOnce(() => {
      return MessageStatus.New;
    });

    mockSigner.getAddress.mockImplementationOnce(() => {
      return "0x";
    });

    const wallet = new Wallet("0x");

    const bridge: Bridge = new ETHBridge(mockProver);

    expect(mockContract.processMessage).not.toHaveBeenCalled();

    expect(mockProver.GenerateProof).not.toHaveBeenCalled();

    await bridge.Claim({
      message: {
        owner: "0x",
        srcChainId: BigNumber.from(CHAIN_ID_TAIKO),
        destChainId: BigNumber.from(CHAIN_ID_MAINNET),
        sender: "0x01",
        gasLimit: BigNumber.from(1),
      } as unknown as Message,
      signal: "0x",
      srcBridgeAddress: "0x",
      destBridgeAddress: "0x",
      signer: wallet,
    });

    expect(mockProver.GenerateProof).toHaveBeenCalled();

    expect(mockContract.processMessage).toHaveBeenCalled();
  });

  it("claim retryMessage", async () => {
    mockContract.getMessageStatus.mockImplementationOnce(() => {
      return MessageStatus.Retriable;
    });

    mockSigner.getAddress.mockImplementationOnce(() => {
      return "0x";
    });

    const wallet = new Wallet("0x");

    const bridge: Bridge = new ETHBridge(mockProver);

    expect(mockContract.retryMessage).not.toHaveBeenCalled();

    expect(mockProver.GenerateProof).not.toHaveBeenCalled();

    await bridge.Claim({
      message: {
        owner: "0x",
        srcChainId: BigNumber.from(CHAIN_ID_TAIKO),
        destChainId: BigNumber.from(CHAIN_ID_MAINNET),
        sender: "0x01",
        gasLimit: BigNumber.from(1),
      } as unknown as Message,
      signal: "0x",
      srcBridgeAddress: "0x",
      destBridgeAddress: "0x",
      signer: wallet,
    });

    expect(mockProver.GenerateProof).not.toHaveBeenCalled();

    expect(mockContract.retryMessage).toHaveBeenCalled();
  });
});
