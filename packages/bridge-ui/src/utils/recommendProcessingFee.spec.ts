const mockChainIdToTokenVaultAddress = jest.fn();
jest.mock("../store/bridge", () => ({
  chainIdToTokenVaultAddress: mockChainIdToTokenVaultAddress,
}));

const mockGet = jest.fn();

import { BigNumber, ethers, Signer } from "ethers";
import { chainIdToTokenVaultAddress } from "../store/bridge";
import { get } from "svelte/store";
import { CHAIN_MAINNET, CHAIN_TKO } from "../domain/chain";
import { ProcessingFeeMethod } from "../domain/fee";
import { ETH, HORSE } from "../domain/token";
import { signer } from "../store/signer";
import {
  erc20DeployedGasLimit,
  erc20NotDeployedGasLimit,
  ethGasLimit,
  recommendProcessingFee,
} from "./recommendProcessingFee";

jest.mock("svelte/store", () => ({
  ...(jest.requireActual("svelte/store") as object),
  get: function () {
    return mockGet();
  },
}));

const mockContract = {
  canonicalToBridged: jest.fn(),
};

const mockProver = {
  GenerateProof: jest.fn(),
};

jest.mock("ethers", () => ({
  /* eslint-disable-next-line */
  ...(jest.requireActual("ethers") as object),
  Contract: function () {
    return mockContract;
  },
}));

const gasPrice = 2;
const mockProvider = {
  getGasPrice: () => {
    return 2;
  },
};

const mockSigner = {};

describe("recommendProcessingFee()", () => {
  beforeEach(() => {
    jest.resetAllMocks();
  });

  it("returns zero if values not set", async () => {
    expect(
      await recommendProcessingFee(
        null,
        CHAIN_MAINNET,
        ProcessingFeeMethod.RECOMMENDED,
        ETH,
        get(signer)
      )
    ).toStrictEqual("0");

    expect(
      await recommendProcessingFee(
        CHAIN_MAINNET,
        null,
        ProcessingFeeMethod.RECOMMENDED,
        ETH,
        get(signer)
      )
    ).toStrictEqual("0");

    expect(
      await recommendProcessingFee(
        CHAIN_MAINNET,
        CHAIN_TKO,
        null,
        ETH,
        get(signer)
      )
    ).toStrictEqual("0");

    expect(
      await recommendProcessingFee(
        CHAIN_TKO,
        CHAIN_MAINNET,
        ProcessingFeeMethod.RECOMMENDED,
        null,
        get(signer)
      )
    ).toStrictEqual("0");

    expect(
      await recommendProcessingFee(
        CHAIN_TKO,
        CHAIN_MAINNET,
        ProcessingFeeMethod.RECOMMENDED,
        ETH,
        null
      )
    ).toStrictEqual("0");
  });

  it("uses ethGasLimit if the token is ETH", async () => {
    mockGet.mockImplementationOnce(() =>
      new Map<number, ethers.providers.JsonRpcProvider>().set(
        CHAIN_TKO.id,
        mockProvider as unknown as ethers.providers.JsonRpcProvider
      )
    );

    const fee = await recommendProcessingFee(
      CHAIN_TKO,
      CHAIN_MAINNET,
      ProcessingFeeMethod.RECOMMENDED,
      ETH,
      mockSigner as unknown as Signer
    );

    const expected = ethers.utils.formatEther(
      BigNumber.from(gasPrice).mul(ethGasLimit)
    );

    expect(fee).toStrictEqual(expected);
  });

  it("uses erc20NotDeployedGasLimit if the token is not ETH and token is not deployed on dest layer", async () => {
    mockGet.mockImplementation((store: any) => {
      if (typeof store === typeof chainIdToTokenVaultAddress) {
        return new Map<number, string>().set(CHAIN_MAINNET.id, "0x12345");
      } else {
        return new Map<number, ethers.providers.JsonRpcProvider>().set(
          CHAIN_TKO.id,
          mockProvider as unknown as ethers.providers.JsonRpcProvider
        );
      }
    });
    mockContract.canonicalToBridged.mockImplementationOnce(
      () => ethers.constants.AddressZero
    );

    const fee = await recommendProcessingFee(
      CHAIN_TKO,
      CHAIN_MAINNET,
      ProcessingFeeMethod.RECOMMENDED,
      HORSE,
      mockSigner as unknown as Signer
    );

    const expected = ethers.utils.formatEther(
      BigNumber.from(gasPrice).mul(erc20NotDeployedGasLimit)
    );

    expect(fee).toStrictEqual(expected);
  });

  it("uses erc20NotDeployedGasLimit if the token is not ETH and token is not deployed on dest layer", async () => {
    mockGet.mockImplementation((store: any) => {
      if (typeof store === typeof chainIdToTokenVaultAddress) {
        return new Map<number, string>().set(CHAIN_MAINNET.id, "0x12345");
      } else {
        return new Map<number, ethers.providers.JsonRpcProvider>().set(
          CHAIN_TKO.id,
          mockProvider as unknown as ethers.providers.JsonRpcProvider
        );
      }
    });

    mockContract.canonicalToBridged.mockImplementationOnce(() => "0x123");

    const fee = await recommendProcessingFee(
      CHAIN_TKO,
      CHAIN_MAINNET,
      ProcessingFeeMethod.RECOMMENDED,
      HORSE,
      mockSigner as unknown as Signer
    );

    const expected = ethers.utils.formatEther(
      BigNumber.from(gasPrice).mul(erc20DeployedGasLimit)
    );

    expect(fee).toStrictEqual(expected);
  });
});
