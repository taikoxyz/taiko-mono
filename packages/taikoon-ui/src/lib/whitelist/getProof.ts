import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import { getAccount } from '@wagmi/core';

import getConfig from '$lib/wagmi/getConfig';

import type { IAddress } from '../../types';
import { whitelist } from './index';

export default function getProof(address?: IAddress): IAddress[] {
  const { config, chainId } = getConfig();

  if (!address) {
    const account = getAccount(config);
    if (!account.address) return [];
    address = account.address;
  }

  const tree = StandardMerkleTree.load(whitelist[chainId]);
  for (const [i, [leafAddress]] of tree.entries()) {
    if (leafAddress.toString().toLowerCase() === address.toString().toLowerCase()) {
      const proof = tree.getProof(i);
      return proof as IAddress[];
    }
  }

  return [];
}
