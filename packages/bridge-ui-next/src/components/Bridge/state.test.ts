import { beforeEach, describe, expect, it } from "vitest";

import { type Token, TokenType } from "$libs/token/types";
import { MOCK_ERC721 } from "$mocks";

import { selectedNFTs, selectedToken } from "./state";

// These stores port Svelte writables: `store.set(v)` replaced the value
// wholesale. zustand v5's setState MERGES non-null objects (and arrays!) via
// Object.assign unless told to replace, which corrupts every store that holds
// a raw array/object value.
describe("bridge state value stores", () => {
  beforeEach(() => {
    selectedToken.setState(null);
    selectedNFTs.setState(null);
  });

  describe("selectedNFTs", () => {
    it("stores a real array (not a merged object) when set over a previous selection", () => {
      selectedNFTs.setState([MOCK_ERC721]);
      selectedNFTs.setState([]);

      const state = selectedNFTs.getState();
      expect(Array.isArray(state)).toBe(true);
      expect(state).toEqual([]);
    });

    it("replaces a previous selection instead of merging stale entries in", () => {
      const otherNFT = { ...MOCK_ERC721, tokenId: 7 };
      selectedNFTs.setState([MOCK_ERC721, otherNFT]);
      selectedNFTs.setState([otherNFT]);

      const state = selectedNFTs.getState();
      expect(state).toHaveLength(1);
      expect(state?.[0].tokenId).toBe(7);
    });
  });

  describe("selectedToken", () => {
    const importedERC20 = {
      name: "Imported",
      symbol: "IMP",
      addresses: { 1: "0x0000000000000000000000000000000000000001" },
      decimals: 18,
      type: TokenType.ERC20,
      imported: true,
      mintable: true,
    } as unknown as Token;

    const eth = {
      name: "Ether",
      symbol: "ETH",
      addresses: { 1: "0x0000000000000000000000000000000000000000" },
      decimals: 18,
      type: TokenType.ETH,
    } as unknown as Token;

    it("does not leak optional fields from the previously selected token", () => {
      selectedToken.setState(importedERC20);
      selectedToken.setState(eth);

      const state = selectedToken.getState();
      expect(state?.symbol).toBe("ETH");
      expect(state && "imported" in state).toBe(false);
      expect(state && "mintable" in state).toBe(false);
    });

    it("does not leak NFT fields (tokenId/metadata) onto a fungible token", () => {
      selectedToken.setState(MOCK_ERC721);
      selectedToken.setState(eth);

      const state = selectedToken.getState();
      expect(state && "tokenId" in state).toBe(false);
      expect(state && "metadata" in state).toBe(false);
    });
  });
});
