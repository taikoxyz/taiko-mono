import { readContract } from '@wagmi/core';
import type { Address } from 'viem';

import { chainId } from '$lib/chain';

import { taikoonTokenAbi, taikoonTokenAddress } from '../../generated/abi';
import { totalWhitelistMintCount } from '../user/totalWhitelistMintCount';
import getConfig from '../wagmi/getConfig';

export async function canMint(address: Address): Promise<boolean> {
  try {
    const config = getConfig();

    const freeMintCount = await totalWhitelistMintCount(address);
    if (freeMintCount === 0) return false;
    const result = await readContract(config, {
      abi: taikoonTokenAbi,
      address: taikoonTokenAddress[chainId],
      functionName: 'canMint',
      args: [address, BigInt(freeMintCount)],
      chainId,
    });

    return result as boolean;
  } catch (e) {
    console.warn(e);
    return false;
  }
}
