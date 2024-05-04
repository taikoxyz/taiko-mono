import type { RequestHandler } from '@sveltejs/kit';

import { NFTService } from '$nftAPI/domain/services/NFTService';
import moralisRepository from '$nftAPI/infrastructure/api/MoralisNFTRepository.server';

const nftService = new NFTService(moralisRepository);

export const POST: RequestHandler = async ({ request }) => {
  try {
    const { address, chainId, refresh } = await request.json();

    const nfts = await nftService.fetchNFTsByAddress({ address, chainId, refresh });

    return new Response(JSON.stringify({ nfts }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
      },
    });
  } catch (error) {
    console.error('Failed to fetch NFTs:', error);
    return new Response(JSON.stringify({ error: 'Failed to retrieve NFT data' }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
      },
    });
  }
};
