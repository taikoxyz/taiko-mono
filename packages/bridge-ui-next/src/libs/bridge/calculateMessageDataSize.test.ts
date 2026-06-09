import { type Token, TokenType } from "$libs/token/types";

import { L1_CHAIN_ID } from "../../tests/mocks/chains";
import {
  MOCK_ERC20,
  MOCK_ERC721,
  MOCK_ERC1155,
} from "../../tests/mocks/tokens";
import { calculateMessageDataSize } from "./calculateMessageDataSize";

vi.mock("$customToken");

const ethToken = {
  name: "Ether",
  addresses: { [L1_CHAIN_ID]: "0x0000000000000000000000000000000000000000" },
  decimals: 18,
  symbol: "ETH",
  type: TokenType.ETH,
} satisfies Token;

describe("calculateMessageDataSize", () => {
  it("should calculate the message data size for ERC20 correctly", async () => {
    // Given
    const token = MOCK_ERC20;
    const chainId = L1_CHAIN_ID;
    const expectedSize = { size: 516 };

    // When
    const result = await calculateMessageDataSize({ token, chainId });

    // Then
    expect(result).toEqual(expectedSize);
  });

  it("should calculate the message data size for ETH correctly", async () => {
    // Given
    const token = ethToken;
    const chainId = L1_CHAIN_ID;
    const expectedSize = { size: 0 };

    // When
    const result = await calculateMessageDataSize({ token, chainId });

    expect(result).toEqual(expectedSize);
  });

  it("should calculate the message data size for ERC721 correctly", async () => {
    // Given
    const token = MOCK_ERC721;
    const chainId = L1_CHAIN_ID;
    const expectedSize = { size: 548 };

    // When
    const result = await calculateMessageDataSize({
      token,
      chainId,
      tokenIds: [1],
    });

    // Then
    expect(result).toEqual(expectedSize);
  });

  it("uses a single placeholder token ID for ERC721 sizing before NFTs are selected", async () => {
    const token = MOCK_ERC721;
    const chainId = L1_CHAIN_ID;

    const result = await calculateMessageDataSize({ token, chainId });
    const explicitSingleNFTResult = await calculateMessageDataSize({
      token,
      chainId,
      tokenIds: [1],
    });

    expect(result).toEqual(explicitSingleNFTResult);
  });

  it("should calculate the message data size for multiple ERC721 correctly", async () => {
    // Given
    const token = MOCK_ERC721;
    const chainId = L1_CHAIN_ID;
    const expectedSize = { size: 612 };

    // When
    const result = await calculateMessageDataSize({
      token,
      chainId,
      tokenIds: [1, 2, 3],
    });

    // Then
    expect(result).toEqual(expectedSize);
  });

  it("should calculate the message data size for multiple ERC1155 correctly", async () => {
    // Given
    const token = MOCK_ERC1155;
    const chainId = L1_CHAIN_ID;
    const expectedSize = { size: 772 };

    // When
    const result = await calculateMessageDataSize({
      token,
      chainId,
      tokenIds: [1, 2, 3],
      amounts: [5, 1, 42],
    });

    // Then
    expect(result).toEqual(expectedSize);
  });

  it("uses single placeholder arrays for ERC1155 sizing before NFTs are selected", async () => {
    const token = MOCK_ERC1155;
    const chainId = L1_CHAIN_ID;

    const result = await calculateMessageDataSize({ token, chainId });
    const explicitSingleNFTResult = await calculateMessageDataSize({
      token,
      chainId,
      tokenIds: [1],
      amounts: [1],
    });

    expect(result).toEqual(explicitSingleNFTResult);
  });
});
