import { readContract } from '@wagmi/core';

import { chainId } from '$lib/chain';

import { taikoonTokenAbi, taikoonTokenAddress } from '../../generated/abi/';
import getConfig from '../../lib/wagmi/getConfig';

export async function tokenURI(tokenId: number): Promise<string> {
  const config = getConfig();

  const result = await readContract(config, {
    abi: taikoonTokenAbi,
    address: taikoonTokenAddress[chainId],
    functionName: 'tokenURI',
    args: [BigInt(tokenId)],
    chainId,
  });

  return result as string;
}
