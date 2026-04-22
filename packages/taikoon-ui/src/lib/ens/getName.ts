import { getEnsName } from '@wagmi/core';
import { type GetEnsNameReturnType } from '@wagmi/core';

import { chainId } from '$lib/chain';

import type { IAddress } from '../../types';
import getConfig from '../wagmi/getConfig';

export default async function getName(address: IAddress): Promise<string> {
  const config = getConfig();
  const ensName = (await getEnsName(config, {
    address,
    chainId,
  })) as GetEnsNameReturnType;
  if (!ensName) throw new Error('No ENS name');
  return ensName;
}
