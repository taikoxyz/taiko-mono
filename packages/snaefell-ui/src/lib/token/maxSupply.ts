import { readContract } from '@wagmi/core';

import { snaefellTokenAbi, snaefellTokenAddress } from '../../generated/abi';
import getConfig from '../wagmi/getConfig';

export async function maxSupply(): Promise<number> {
  const { config, chainId } = getConfig();

  const result = await readContract(config, {
    abi: snaefellTokenAbi,
    address: snaefellTokenAddress[chainId],
    functionName: 'maxSupply',
    chainId,
  });

  return parseInt(result.toString(16), 16);
}
