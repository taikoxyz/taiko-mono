import { getAccount, readContract } from '@wagmi/core';

import { taikoonTokenAbi, taikoonTokenAddress } from '../../generated/abi';
import type { IAddress } from '../../types';
import { totalWhitelistMintCount } from '../user/totalWhitelistMintCount';
import getConfig from '../wagmi/getConfig';

export async function canMint(): Promise<boolean> {
  const { config, chainId } = getConfig();

  const account = getAccount(config);
  if (!account.address) return false;
  const accountAddress = account.address as IAddress;

  const freeMintCount = await totalWhitelistMintCount();

  const result = await readContract(config, {
    abi: taikoonTokenAbi,
    address: taikoonTokenAddress[chainId],
    functionName: 'canMint',
    args: [accountAddress, BigInt(freeMintCount)],
    chainId,
  });
  return result as boolean;
}
