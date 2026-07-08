import type { Address } from "viem";
import { beforeEach, describe, expect, it, vi } from "vitest";

const { getWalletNFTsMock } = vi.hoisted(() => ({
  getWalletNFTsMock: vi.fn(),
}));

vi.mock("server-only", () => ({}));
vi.mock("moralis", () => ({
  default: {
    start: vi.fn().mockResolvedValue(undefined),
    EvmApi: { nft: { getWalletNFTs: getWalletNFTsMock } },
  },
}));
// Identity mapper: the repository's caching behavior is under test, not the
// Moralis payload mapping.
vi.mock("$nftAPI/infrastructure/mappers/nft/MoralisNFTMapper", () => ({
  mapToNFTFromMoralis: (nft: unknown) => nft,
}));

import repository from "./MoralisNFTRepository.server";

const ADDRESS_A = "0x000000000000000000000000000000000000aaa1" as Address;
const ADDRESS_B = "0x000000000000000000000000000000000000bbb2" as Address;

function moralisPage(items: string[], cursor: string | null = null) {
  return {
    pagination: { cursor },
    result: items.map((id) => ({ id })),
  };
}

describe("MoralisNFTRepository caching", () => {
  beforeEach(() => {
    getWalletNFTsMock.mockReset();
  });

  it("never returns one address's cached NFTs to a different address", async () => {
    getWalletNFTsMock.mockImplementation(({ address }: { address: Address }) =>
      Promise.resolve(
        address === ADDRESS_A ? moralisPage(["nft-A"]) : moralisPage(["nft-B"]),
      ),
    );

    const forA = await repository.findByAddress({
      address: ADDRESS_A,
      chainId: 1,
    });
    const forB = await repository.findByAddress({
      address: ADDRESS_B,
      chainId: 1,
    });

    expect(forA).toEqual([{ id: "nft-A" }]);
    expect(forB).toEqual([{ id: "nft-B" }]);
    // Both addresses must actually hit the API — no shared has-fetched-all
    // short-circuit across users.
    expect(getWalletNFTsMock).toHaveBeenCalledTimes(2);
  });

  it("does not reuse another chain's cache for the same address", async () => {
    getWalletNFTsMock.mockImplementation(({ chain }: { chain: number }) =>
      Promise.resolve(moralisPage([`nft-chain-${chain}`])),
    );

    const onChain1 = await repository.findByAddress({
      address: "0x000000000000000000000000000000000000ccc3" as Address,
      chainId: 1,
    });
    const onChain2 = await repository.findByAddress({
      address: "0x000000000000000000000000000000000000ccc3" as Address,
      chainId: 2,
    });

    expect(onChain1).toEqual([{ id: "nft-chain-1" }]);
    expect(onChain2).toEqual([{ id: "nft-chain-2" }]);
  });

  it("serves a fully-fetched list from cache for the SAME address without re-hitting the API", async () => {
    getWalletNFTsMock.mockResolvedValue(moralisPage(["nft-D"]));
    const address = "0x000000000000000000000000000000000000ddd4" as Address;

    const first = await repository.findByAddress({ address, chainId: 1 });
    const second = await repository.findByAddress({ address, chainId: 1 });

    expect(first).toEqual([{ id: "nft-D" }]);
    expect(second).toEqual([{ id: "nft-D" }]);
    expect(getWalletNFTsMock).toHaveBeenCalledTimes(1);
  });

  it("refetches when refresh is requested", async () => {
    getWalletNFTsMock.mockResolvedValue(moralisPage(["nft-E"]));
    const address = "0x000000000000000000000000000000000000eee5" as Address;

    await repository.findByAddress({ address, chainId: 1 });
    await repository.findByAddress({ address, chainId: 1, refresh: true });

    expect(getWalletNFTsMock).toHaveBeenCalledTimes(2);
  });

  it("keeps pagination cursors isolated per address", async () => {
    const addressPaged = "0x000000000000000000000000000000000000fff6" as Address;
    const addressOther = "0x0000000000000000000000000000000000000117" as Address;

    getWalletNFTsMock.mockImplementation(
      ({ address, cursor }: { address: Address; cursor: string }) => {
        if (address === addressPaged) {
          return Promise.resolve(
            cursor === ""
              ? moralisPage(["paged-1"], "cursor-page-2")
              : moralisPage(["paged-2"]),
          );
        }
        return Promise.resolve(moralisPage(["other-1"]));
      },
    );

    // First page for the paginated wallet…
    const page1 = await repository.findByAddress({
      address: addressPaged,
      chainId: 1,
    });
    expect(page1).toEqual([{ id: "paged-1" }]);

    // …an interleaved request from another wallet must not steal or advance
    // the paginated wallet's cursor…
    const other = await repository.findByAddress({
      address: addressOther,
      chainId: 1,
    });
    expect(other).toEqual([{ id: "other-1" }]);

    // …and the paginated wallet resumes from ITS cursor, accumulating only
    // its own NFTs.
    const page2 = await repository.findByAddress({
      address: addressPaged,
      chainId: 1,
    });
    expect(page2).toEqual([{ id: "paged-1" }, { id: "paged-2" }]);
  });
});
