import { getAccount } from '@wagmi/core';

import getConfig from '$lib/wagmi/getConfig';

import type { IAddress } from '../../types';
import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import { whitelist } from '.';

export default async function getProof(address?: IAddress): Promise<IAddress[]> {
  const { config, chainId } = getConfig();

  function legacyProofFetch(_address: string) {

    const tree = StandardMerkleTree.load(whitelist[chainId]);
    for (const [i, [leafAddress]] of tree.entries()) {
      if (leafAddress.toString().toLowerCase() === _address.toString().toLowerCase()) {
        const proof = tree.getProof(i);
        return proof as IAddress[];
      }
    }
  }

  try {
    if (!address) {
      const account = getAccount(config);
      if (!account.address) return [];
      address = account.address;
    }

    address = '0x616b958904940c789e104Cb39bd2BFF82427CCCB'

    const url = ['https://qa.trailblazer.taiko.xyz/api/snaefell?address=', address, '&chainId=', chainId].join('');

    console.log({url})
    const res = await fetch(url);
    const data = await res.json();
    const proof = JSON.parse(data.proof);

    console.log('fetched', {proof})

    //return proof as IAddress[];
    const legacyProof = legacyProofFetch(address);

    console.log('legacy', {legacyProof})

  } catch (e) {
    console.error(`Error with getProof chainId ${chainId}:`, e);
  }

  return [];
}
