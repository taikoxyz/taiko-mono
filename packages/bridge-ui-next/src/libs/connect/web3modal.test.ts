import { createWeb3Modal } from "@web3modal/wagmi/react";
import { describe, expect, it, vi } from "vitest";

const CHAIN_IMAGES = { 1: "/chains/ethereum.svg", 167000: "/chains/taiko.svg" };

vi.mock("@web3modal/wagmi/react", () => ({
  createWeb3Modal: vi.fn(() => ({})),
}));
vi.mock("@/libs/wagmi", () => ({
  config: {},
}));
vi.mock("@/libs/chain", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@/libs/chain")>()),
  getChainImages: () => CHAIN_IMAGES,
}));

import { initWeb3Modal } from "./web3modal";

describe("initWeb3Modal", () => {
  it("passes the configured chain logos to web3modal (parity with the SvelteKit app)", () => {
    initWeb3Modal();

    expect(createWeb3Modal).toHaveBeenCalledTimes(1);
    expect(createWeb3Modal).toHaveBeenCalledWith(
      expect.objectContaining({ chainImages: CHAIN_IMAGES }),
    );
  });
});
