import { getAccount } from '@wagmi/core';

import getConfig from '$lib/wagmi/getConfig';

import type { IAddress } from '../../types';

export default async function getProof(address?: IAddress): Promise<IAddress[]> {
  const { config, chainId } = getConfig();

  try {
    if (!address) {
      const account = getAccount(config);
      if (!account.address) return [];
      address = account.address;
    }

    const url = ['https://qa.trailblazer.taiko.xyz/api/final?address=', address, '&chainId=', chainId].join('');

    const res = await fetch(url);
    const data = await res.json();
    const { proof } = data;

    return proof as IAddress[];
  } catch (e) {
    console.error(`Error with getProof chainId ${chainId}:`, e);
  }

  return [];
}
