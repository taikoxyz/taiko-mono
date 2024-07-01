import { createPublicClient, http } from 'viem';
import { holesky } from 'viem/chains';

export default async function publicClient() {
  const client = createPublicClient({
    chain: holesky,
    transport: http('https://1rpc.io/holesky'),
  });
  return client;
}
