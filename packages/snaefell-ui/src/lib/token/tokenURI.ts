import { readContract } from '@wagmi/core';

import { snaefellTokenAbi, snaefellTokenAddress } from '../../generated/abi/';
import getConfig from '../../lib/wagmi/getConfig';
import type { IChainId } from '../../types';

export async function tokenURI(tokenId: number): Promise<string> {
  const { config, chainId } = getConfig();

  const result = await readContract(config, {
    abi: snaefellTokenAbi,
    address: snaefellTokenAddress[chainId as IChainId],
    functionName: 'tokenURI',
    args: [BigInt(tokenId)],
    chainId,
  });

  return result as string;
}
