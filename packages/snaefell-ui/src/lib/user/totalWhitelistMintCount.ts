import { getAccount } from '@wagmi/core';

import getConfig from '../wagmi/getConfig';
import { whitelist } from '../whitelist';

export async function totalWhitelistMintCount(): Promise<number> {
  const { config, chainId } = getConfig();

  const account = getAccount(config);
  if (!account.address) return 0;

  const { allocation } = whitelist[chainId];
  return allocation[account.address.toLowerCase()] || 0;
}
