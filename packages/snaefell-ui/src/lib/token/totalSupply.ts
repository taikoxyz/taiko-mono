import { readContract } from '@wagmi/core';

import { snaefellTokenAbi, snaefellTokenAddress } from '../../generated/abi';
import getConfig from '../../lib/wagmi/getConfig';
import type { IChainId } from '../../types';

export async function totalSupply(): Promise<number> {
  try {
    const { config, chainId } = getConfig();

    const result = await readContract(config, {
      abi: snaefellTokenAbi,
      address: snaefellTokenAddress[chainId as IChainId],
      functionName: 'totalSupply',
      chainId,
    });

    return parseInt(result.toString(16), 16);
  } catch (e) {
    console.error(e);
    return 0;
  }
}
