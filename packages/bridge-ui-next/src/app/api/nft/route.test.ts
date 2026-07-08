import { beforeEach, describe, expect, it, vi } from "vitest";

const { fetchNFTsByAddressMock } = vi.hoisted(() => ({
  fetchNFTsByAddressMock: vi.fn(),
}));

vi.mock("$nftAPI/infrastructure/api/MoralisNFTRepository.server", () => ({
  default: {},
}));
vi.mock("$nftAPI/domain/services/NFTService", () => ({
  NFTService: class {
    fetchNFTsByAddress = fetchNFTsByAddressMock;
  },
}));

import { POST } from "./route";

const VALID_ADDRESS = "0x63FaC9201494f0bd17B9892B9fae4d52fe3BD377";

function post(body: unknown): Promise<Response> {
  return POST(
    new Request("http://localhost/api/nft", {
      method: "POST",
      body: typeof body === "string" ? body : JSON.stringify(body),
      headers: { "Content-Type": "application/json" },
    }),
  );
}

describe("POST /api/nft input validation", () => {
  beforeEach(() => {
    fetchNFTsByAddressMock.mockReset();
    fetchNFTsByAddressMock.mockResolvedValue([{ id: "nft" }]);
  });

  it("returns 200 with NFTs for a valid request", async () => {
    const response = await post({
      address: VALID_ADDRESS,
      chainId: 167000,
      refresh: false,
    });

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ nfts: [{ id: "nft" }] });
    expect(fetchNFTsByAddressMock).toHaveBeenCalledWith({
      address: VALID_ADDRESS,
      chainId: 167000,
      refresh: false,
    });
  });

  it("rejects a malformed address with 400 without hitting the NFT service", async () => {
    const response = await post({
      address: "not-an-address",
      chainId: 167000,
    });

    expect(response.status).toBe(400);
    expect(fetchNFTsByAddressMock).not.toHaveBeenCalled();
  });

  it("rejects a missing/non-integer chainId with 400", async () => {
    const missing = await post({ address: VALID_ADDRESS });
    const nonInteger = await post({
      address: VALID_ADDRESS,
      chainId: "167000; DROP TABLE",
    });

    expect(missing.status).toBe(400);
    expect(nonInteger.status).toBe(400);
    expect(fetchNFTsByAddressMock).not.toHaveBeenCalled();
  });

  it("rejects a non-JSON body with 400, not 500", async () => {
    const response = await post("this is not json");

    expect(response.status).toBe(400);
    expect(fetchNFTsByAddressMock).not.toHaveBeenCalled();
  });

  it("coerces refresh to a strict boolean", async () => {
    await post({ address: VALID_ADDRESS, chainId: 1, refresh: "yes" });

    expect(fetchNFTsByAddressMock).toHaveBeenCalledWith({
      address: VALID_ADDRESS,
      chainId: 1,
      refresh: false,
    });
  });
});
