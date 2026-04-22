import { readContract } from '@wagmi/core';

import { chainId } from '$lib/chain';
import { config } from '$wagmi-config';

import { taikoonTokenAbi, taikoonTokenAddress } from '../../generated/abi/';

export async function name(): Promise<string> {
  const result = await readContract(config, {
    abi: taikoonTokenAbi,
    address: taikoonTokenAddress[chainId],
    functionName: 'name',
    chainId,
  });

  return result as string;
}
