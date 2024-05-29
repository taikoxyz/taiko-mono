import { readContract } from '@wagmi/core';

import { snaefellTokenAbi, snaefellTokenAddress } from '../../generated/abi';
import getConfig from '../../lib/wagmi/getConfig';
import type { IAddress, IChainId } from '../../types';
import { balanceOf } from './balanceOf';

export async function tokenOfOwner(address: IAddress): Promise<number[]> {
  const balance = await balanceOf(address);

  const tokenIds = [];
  const { config, chainId } = getConfig();

  for (const tokenIdx of Array(balance).keys()) {
    const tokenIdRaw = (await readContract(config, {
      abi: snaefellTokenAbi,
      address: snaefellTokenAddress[chainId as IChainId],
      functionName: 'tokenOfOwnerByIndex',
      args: [address, BigInt(tokenIdx)],
      chainId,
    })) as bigint;
    tokenIds.push(parseInt(tokenIdRaw.toString()));
  }

  return tokenIds;
}
