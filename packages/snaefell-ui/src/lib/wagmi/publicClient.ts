import { createPublicClient, http } from 'viem';

import { chainIdToChain } from '$lib/chain/chains';

const devnet = chainIdToChain(167001);

export default async function publicClient() {
  const client = createPublicClient({
    chain: devnet,
    transport: http('https://rpc.internal.taiko.xyz'),
  });

  return client;
}
