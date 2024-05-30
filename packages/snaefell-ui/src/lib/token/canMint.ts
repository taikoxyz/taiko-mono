import { getAccount, readContract } from '@wagmi/core';

import { snaefellTokenAbi, snaefellTokenAddress } from '../../generated/abi';
import type { IAddress, IChainId } from '../../types';
import { totalWhitelistMintCount } from '../user/totalWhitelistMintCount';
import getConfig from '../wagmi/getConfig';

export async function canMint(): Promise<boolean> {
  try {
    const { config, chainId } = getConfig();

    const account = getAccount(config);
    if (!account.address) return false;
    const accountAddress = account.address as IAddress;

    const freeMintCount = await totalWhitelistMintCount();
    if (freeMintCount === 0) return false;
    const result = await readContract(config, {
      abi: snaefellTokenAbi,
      address: snaefellTokenAddress[chainId as IChainId],
      functionName: 'canMint',
      args: [accountAddress, BigInt(freeMintCount)],
      chainId,
    });
    return result as boolean;
  } catch (e) {
    console.warn(e);
    return false;
  }
}
