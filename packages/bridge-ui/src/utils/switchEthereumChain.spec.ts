import type { Ethereum } from "@wagmi/core";
import { CHAIN_MAINNET } from "../domain/chain";
import { switchEthereumChain } from "./switchEthereumChain";

const mockEthereum = {
  request: jest.fn(),
};

describe("switchEthereumChain()", () => {
  beforeEach(() => {
    jest.resetAllMocks();
  });

  it("throws when wallet_switchethereumchain and wallet_addethereumchain throws", async () => {
    mockEthereum.request.mockImplementation(() => {
      class EthereumError extends Error {
        public code: number;
        constructor(message: string, code: number) {
          super(message);
          this.code = code;
        }
      }

      throw new EthereumError("fake", 4902);
    });
    expect(mockEthereum.request).not.toHaveBeenCalled();

    await expect(
      switchEthereumChain(mockEthereum as unknown as Ethereum, CHAIN_MAINNET)
    ).rejects.toThrowError("fake");
  });

  it("succeeds when wallet_switchEthereumChain and addEthereumChain do not throw", async () => {
    mockEthereum.request.mockImplementation(() => {});
    expect(mockEthereum.request).not.toHaveBeenCalled();

    await expect(
      switchEthereumChain(mockEthereum as unknown as Ethereum, CHAIN_MAINNET)
    ).resolves;
  });
});
