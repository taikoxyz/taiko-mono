import { getEnsAddress } from '@wagmi/core';
import { type GetEnsAddressReturnType } from '@wagmi/core';
import { normalize } from 'viem/ens';

import { chainId } from '$lib/chain';

import type { IAddress } from '../../types';
import getConfig from '../wagmi/getConfig';

export default async function getAddress(ensName: string): Promise<IAddress> {
  const config = getConfig();
  const address = (await getEnsAddress(config, {
    name: normalize(ensName),
    chainId,
  })) as GetEnsAddressReturnType;

  if (!address) throw new Error('No ENS name');
  return address;
}
