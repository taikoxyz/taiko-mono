import { getPublicClient } from "@wagmi/core";

import { estimateMessageGasLimit } from "$libs/bridge/estimateMessageGasLimit";
import { getTokenAddresses } from "$libs/token/getTokenAddresses";
import { type Token, TokenType } from "$libs/token/types";

import { L1_CHAIN_ID, L2_CHAIN_ID } from "../../tests/mocks/chains";
import {
  MOCK_ERC20,
  MOCK_ERC721,
  MOCK_ERC1155,
} from "../../tests/mocks/tokens";
import {
  applyRelayerGasLimitPadding,
  calculateProcessingFee,
  recommendProcessingFee,
} from "./recommendProcessingFee";

vi.mock("@wagmi/core");
vi.mock("$libs/bridge/estimateMessageGasLimit");
vi.mock("$customToken");
vi.mock("$bridgeConfig");
vi.mock("$libs/chain", () => ({
  chains: [],
  getConfiguredChainIds: () => [1, 2],
}));
vi.mock("$libs/wagmi", () => ({ config: {} }));
vi.mock("$libs/wagmi/client", () => ({ config: {} }));
vi.mock("$libs/token/getTokenAddresses");

const mockClient = {
  request: vi.fn(),
  getBlock: vi.fn(),
  estimateMaxPriorityFeePerGas: vi.fn(),
  getGasPrice: vi.fn(),
};

const ethToken = {
  name: "Ether",
  addresses: { [L1_CHAIN_ID]: "0x0000000000000000000000000000000000000000" },
  decimals: 18,
  symbol: "ETH",
  type: TokenType.ETH,
} satisfies Token;

describe("recommendedProcessingFee", () => {
  beforeAll(() => {
    vi.mocked(getPublicClient).mockReturnValue(mockClient);
    vi.mocked(mockClient.getBlock).mockReturnValue({ baseFeePerGas: 11n });
    vi.mocked(mockClient.estimateMaxPriorityFeePerGas).mockReturnValue(42n);
  });

  beforeEach(() => {
    vi.mocked(estimateMessageGasLimit).mockReset();
  });

  describe("ETH fees", () => {
    it("should calculate the recommended processing fee for ETH", async () => {
      // Given
      const token = ethToken;
      const srcChainId = L1_CHAIN_ID;
      const destChainId = L2_CHAIN_ID;

      const gasLimit = 806_657;

      const baseFee = 11n;
      const maxPriorityFee = 10_000_000n;
      const feeMultiplicator = 1;

      const expectedFee = calculateProcessingFee({
        relayerGasLimit: applyRelayerGasLimitPadding(BigInt(gasLimit), true),
        baseFee,
        maxPriorityFeePerGas: maxPriorityFee,
        feeMultiplier: feeMultiplicator,
      });

      vi.mocked(estimateMessageGasLimit).mockResolvedValue(gasLimit);

      // When
      const result = await recommendProcessingFee({
        token,
        destChainId,
        srcChainId,
      });

      // Then
      expect(result).toBe(BigInt(expectedFee));
    });
  });

  describe("ERC20 fees", () => {
    it("should calculate the recommended processing fee for deployed ERC20", async () => {
      // Given
      const token = MOCK_ERC20;
      const srcChainId = L1_CHAIN_ID;
      const destChainId = L2_CHAIN_ID;

      const gasLimit = 1_315_360;

      const baseFee = 11n;
      const maxPriorityFee = 10_000_000n;
      const feeMultiplicator = 1;

      const expectedFee = calculateProcessingFee({
        relayerGasLimit: applyRelayerGasLimitPadding(BigInt(gasLimit), true),
        baseFee,
        maxPriorityFeePerGas: maxPriorityFee,
        feeMultiplier: feeMultiplicator,
      });

      vi.mocked(estimateMessageGasLimit).mockResolvedValue(gasLimit);
      vi.mocked(getTokenAddresses).mockResolvedValue({
        bridged: {
          chainId: L1_CHAIN_ID,
          address: MOCK_ERC20.addresses[L1_CHAIN_ID],
        },
        canonical: {
          chainId: L2_CHAIN_ID,
          address: MOCK_ERC20.addresses[L2_CHAIN_ID],
        },
      });

      // When
      const result = await recommendProcessingFee({
        token,
        destChainId,
        srcChainId,
      });

      // Then
      expect(result).toBe(BigInt(expectedFee));
    });
  });

  describe("ERC721 fees", () => {
    it("should calculate the recommended processing fee for deployed ERC721", async () => {
      // Given
      const token = MOCK_ERC721;
      const srcChainId = L1_CHAIN_ID;
      const destChainId = L2_CHAIN_ID;

      const gasLimit = 1_915_872;

      const baseFee = 11n;
      const maxPriorityFee = 10_000_000n;
      const feeMultiplicator = 1;

      const expectedFee = calculateProcessingFee({
        relayerGasLimit: applyRelayerGasLimitPadding(BigInt(gasLimit), true),
        baseFee,
        maxPriorityFeePerGas: maxPriorityFee,
        feeMultiplier: feeMultiplicator,
      });

      vi.mocked(estimateMessageGasLimit).mockResolvedValue(gasLimit);
      vi.mocked(getTokenAddresses).mockResolvedValue({
        bridged: {
          chainId: L1_CHAIN_ID,
          address: MOCK_ERC721.addresses[L1_CHAIN_ID],
        },
        canonical: {
          chainId: L2_CHAIN_ID,
          address: MOCK_ERC721.addresses[L2_CHAIN_ID],
        },
      });

      // When
      const result = await recommendProcessingFee({
        token,
        destChainId,
        srcChainId,
      });

      // Then
      expect(result).toBe(BigInt(expectedFee));
    });
  });

  describe("ERC1155 fees", () => {
    it("should calculate the recommended processing fee for deployed ERC1155", async () => {
      // Given
      const token = MOCK_ERC1155;
      const srcChainId = L1_CHAIN_ID;
      const destChainId = L2_CHAIN_ID;

      const gasLimit = 1_919_456;

      const baseFee = 11n;
      const maxPriorityFee = 10_000_000n;
      const feeMultiplicator = 1;

      const expectedFee = calculateProcessingFee({
        relayerGasLimit: applyRelayerGasLimitPadding(BigInt(gasLimit), true),
        baseFee,
        maxPriorityFeePerGas: maxPriorityFee,
        feeMultiplier: feeMultiplicator,
      });

      vi.mocked(estimateMessageGasLimit).mockResolvedValue(gasLimit);
      vi.mocked(getTokenAddresses).mockResolvedValue({
        bridged: {
          chainId: L1_CHAIN_ID,
          address: MOCK_ERC1155.addresses[L1_CHAIN_ID],
        },
        canonical: {
          chainId: L2_CHAIN_ID,
          address: MOCK_ERC1155.addresses[L2_CHAIN_ID],
        },
      });

      // When
      const result = await recommendProcessingFee({
        token,
        destChainId,
        srcChainId,
      });

      // Then
      expect(result).toBe(BigInt(expectedFee));
    });
  });

  describe("reported failing transaction simulation", () => {
    it("ceil-rounds decimal fee multipliers", () => {
      const recommendedFee = calculateProcessingFee({
        relayerGasLimit: 1n,
        baseFee: 1n,
        maxPriorityFeePerGas: 0n,
        feeMultiplier: "1.1",
      });

      expect(recommendedFee).toBe(3n);
    });

    it("prices the reported ERC20 deployed message above the old underpriced fee", () => {
      const reportedMessageGasLimit = 1_315_360n;
      const reportedProcessingFee = 34_500_000_000_000n;
      const destChainBaseFee = 8_756_091n;
      const gasTipCap = 38_434_172n;

      const relayerGasLimit = applyRelayerGasLimitPadding(
        reportedMessageGasLimit,
        true,
      );
      const recommendedFee = calculateProcessingFee({
        relayerGasLimit,
        baseFee: destChainBaseFee,
        maxPriorityFeePerGas: gasTipCap,
        feeMultiplier: 1,
      });

      expect(relayerGasLimit).toBe(1_446_896n);
      expect(recommendedFee).toBe(80_948_555_817_184n);
      expect(recommendedFee).toBeGreaterThan(reportedProcessingFee);
    });
  });
});
