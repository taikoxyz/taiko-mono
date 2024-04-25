import { createPublicClient, http } from 'viem';
import { hardhat } from 'viem/chains';

export default async function publicClient() {
  const client = createPublicClient({
    chain: hardhat,
    transport: http('http://localhost:8545'),
  });

  return client;
}
