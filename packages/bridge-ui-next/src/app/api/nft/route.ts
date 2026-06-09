import { NFTService } from "$nftAPI/domain/services/NFTService";
import moralisRepository from "$nftAPI/infrastructure/api/MoralisNFTRepository.server";

// The Moralis repository is a stateful singleton (cursor/accumulated NFTs) and reads
// the server-only MORALIS_API_KEY, so this route must run on the Node.js runtime and
// never be statically optimized.
export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const nftService = new NFTService(moralisRepository);

export async function POST(request: Request): Promise<Response> {
  try {
    const { address, chainId, refresh } = await request.json();

    const nfts = await nftService.fetchNFTsByAddress({
      address,
      chainId,
      refresh,
    });

    return new Response(JSON.stringify({ nfts }), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
      },
    });
  } catch (error) {
    console.error("Failed to fetch NFTs:", error);
    return new Response(
      JSON.stringify({ error: "Failed to retrieve NFT data" }),
      {
        status: 500,
        headers: {
          "Content-Type": "application/json",
        },
      },
    );
  }
}
