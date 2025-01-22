import { readContract } from '@wagmi/core';

import { chainId } from '$lib/chain';
import { config } from '$wagmi-config';

import { taikoonTokenAbi, taikoonTokenAddress } from '../../generated/abi/';
import type { IAddress } from '../../types';

export async function ownerOf(tokenId: number): Promise<IAddress> {
  const result = await readContract(config, {
    abi: taikoonTokenAbi,
    address: taikoonTokenAddress[chainId],
    functionName: 'ownerOf',
    args: [BigInt(tokenId)],
    chainId,
  });

  return result as IAddress;
}
