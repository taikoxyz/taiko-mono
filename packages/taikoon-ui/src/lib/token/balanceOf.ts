import { readContract } from '@wagmi/core';

import { chainId } from '$lib/chain';
import { config } from '$wagmi-config';

import { taikoonTokenAbi, taikoonTokenAddress } from '../../generated/abi/';
import type { IAddress } from '../../types';

export async function balanceOf(address: IAddress): Promise<number> {
  const result = await readContract(config, {
    abi: taikoonTokenAbi,
    address: taikoonTokenAddress[chainId],
    functionName: 'balanceOf',
    args: [address],
    chainId,
  });

  return parseInt(result.toString());
}
