import { getBalance as wagmiGetBalance } from '@wagmi/core';
import { type GetBalanceReturnType } from '@wagmi/core';

import type { IAddress } from '../../types';
import getConfig from './getConfig';

export default async function getBalance(address: IAddress): Promise<bigint> {
  const { config, chainId } = getConfig();

  const balance = (await wagmiGetBalance(config, {
    address,
    chainId,
  })) as GetBalanceReturnType;
  return balance.value;
}
