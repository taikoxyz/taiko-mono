import { getPublicClient } from "@wagmi/core";
import { getContract } from "viem";

import { type Token, TokenType } from "$libs/token/types";

import { L1_CHAIN_ID, L2_CHAIN_ID } from "../../tests/mocks/chains";
import { MOCK_ERC20 } from "../../tests/mocks/tokens";
import { estimateMessageGasLimit } from "./estimateMessageGasLimit";

vi.mock("@wagmi/core");
vi.mock("$customToken");
vi.mock("$bridgeConfig");
vi.mock("$libs/chain", () => ({
  chains: [],
  getConfiguredChainIds: () => [1, 2],
}));
vi.mock("$libs/wagmi", () => ({ config: {} }));
vi.mock("$libs/wagmi/client", () => ({ config: {} }));
vi.mock("viem", async () => {
  const viem = await vi.importActual<typeof import("viem")>("viem");
  return {
    ...viem,
    getContract: vi.fn(),
  };
});

const mockContract = {
  read: {
    getMessageMinGasLimit: vi.fn(),
  },
};

const ethToken = {
  name: "Ether",
  addresses: { [L1_CHAIN_ID]: "0x0000000000000000000000000000000000000000" },
  decimals: 18,
  symbol: "ETH",
  type: TokenType.ETH,
} satisfies Token;

describe("estimateMessageGasLimit", () => {
  beforeEach(() => {
    vi.mocked(getPublicClient).mockReturnValue(
      {} as ReturnType<typeof getPublicClient>,
    );
    vi.mocked(getContract).mockReturnValue(
      mockContract as unknown as ReturnType<typeof getContract>,
    );
    mockContract.read.getMessageMinGasLimit.mockReset();
  });

  it("uses the destination bridge minimum for ETH messages", async () => {
    mockContract.read.getMessageMinGasLimit.mockResolvedValue(806_656);

    const gasLimit = await estimateMessageGasLimit({
      token: ethToken,
      srcChainId: L1_CHAIN_ID,
      destChainId: L2_CHAIN_ID,
    });

    expect(mockContract.read.getMessageMinGasLimit).toHaveBeenCalledWith([0n]);
    expect(gasLimit).toBe(806_657);
  });

  it("uses the same deployed ERC20 message gas limit as the bridge transaction", async () => {
    mockContract.read.getMessageMinGasLimit.mockResolvedValue(815_360);

    const gasLimit = await estimateMessageGasLimit({
      token: MOCK_ERC20,
      srcChainId: L1_CHAIN_ID,
      destChainId: L2_CHAIN_ID,
      isTokenAlreadyDeployed: true,
    });

    expect(mockContract.read.getMessageMinGasLimit).toHaveBeenCalledWith([
      516n,
    ]);
    expect(gasLimit).toBe(1_315_360);
  });
});
