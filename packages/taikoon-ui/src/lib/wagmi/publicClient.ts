import { createPublicClient, http } from 'viem';
import { taiko } from 'viem/chains';

export default async function publicClient() {
  const client = createPublicClient({
    chain: taiko,
    transport: http('https://rpc.mainnet.taiko.xyz'),
  });
  return client;
}
