import { type Address, isAddress } from "viem";

import { NFTService } from "$nftAPI/domain/services/NFTService";
import moralisRepository from "$nftAPI/infrastructure/api/MoralisNFTRepository.server";

// The Moralis repository is a stateful singleton (per-wallet cursor/NFT cache) and
// reads the server-only MORALIS_API_KEY, so this route must run on the Node.js
// runtime and never be statically optimized.
export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const nftService = new NFTService(moralisRepository);

// Wallet-derived data: never let proxies or the browser cache another
// wallet's response.
const JSON_NO_STORE = {
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
};

function badRequest(message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status: 400,
    headers: JSON_NO_STORE,
  });
}

export async function POST(request: Request): Promise<Response> {
  // This route is unauthenticated and proxies to Moralis under the server's
  // API key — validate everything before it reaches the upstream call.
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return badRequest("Request body must be valid JSON");
  }

  const { address, chainId, refresh } = (body ?? {}) as {
    address?: unknown;
    chainId?: unknown;
    refresh?: unknown;
  };

  if (typeof address !== "string" || !isAddress(address)) {
    return badRequest("`address` must be a valid Ethereum address");
  }
  if (
    typeof chainId !== "number" ||
    !Number.isSafeInteger(chainId) ||
    chainId <= 0
  ) {
    return badRequest("`chainId` must be a positive integer");
  }

  try {
    const nfts = await nftService.fetchNFTsByAddress({
      address: address as Address,
      chainId,
      refresh: refresh === true,
    });

    return new Response(JSON.stringify({ nfts }), {
      status: 200,
      headers: JSON_NO_STORE,
    });
  } catch (error) {
    console.error("Failed to fetch NFTs:", error);
    return new Response(
      JSON.stringify({ error: "Failed to retrieve NFT data" }),
      {
        status: 500,
        headers: JSON_NO_STORE,
      },
    );
  }
}
