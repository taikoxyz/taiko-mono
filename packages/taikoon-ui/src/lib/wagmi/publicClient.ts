import { createPublicClient, http } from 'viem';
import { holesky } from 'viem/chains';

//const devnet = chainIdToChain(167001);

export default async function publicClient() {
  /*
  const client = createPublicClient({
    chain: devnet,
    transport: http('https://rpc.internal.taiko.xyz'),
  });*/

  const client = createPublicClient({
    chain: holesky,
    transport: http('https://1rpc.io/holesky'),
  });
  return client;
}
