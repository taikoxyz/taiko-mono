import { readContracts } from '@wagmi/core';

import { chainId } from '$lib/chain';

import { taikoonTokenAbi, taikoonTokenAddress } from '../../generated/abi';
import getConfig from '../../lib/wagmi/getConfig';
import type { IAddress } from '../../types';
import { balanceOf } from './balanceOf';

export async function tokenOfOwner(address: IAddress): Promise<number[]> {
  const balance = await balanceOf(address);

  const config = getConfig();

  const params = { contracts: [] } as any;

  for (const tokenIdx of Array(balance).keys()) {
    params.contracts.push({
      abi: taikoonTokenAbi,
      address: taikoonTokenAddress[chainId],
      functionName: 'tokenOfOwnerByIndex',
      args: [address, BigInt(tokenIdx)],
      chainId,
    });
  }

  const results = await readContracts(config, params);

  return results.map((item: any) => parseInt(item.result.toString()));
}
