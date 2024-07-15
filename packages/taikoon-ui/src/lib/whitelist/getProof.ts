import { StandardMerkleTree } from '@openzeppelin/merkle-tree';

import { chainId } from '$lib/chain';

import type { IAddress } from '../../types';
import { whitelist } from './index';

export default function getProof(address: IAddress): IAddress[] {
  try {
    const tree = StandardMerkleTree.load(whitelist[chainId]);
    for (const [i, [leafAddress]] of tree.entries()) {
      if (leafAddress.toString().toLowerCase() === address.toString().toLowerCase()) {
        const proof = tree.getProof(i);

        return proof as IAddress[];
      }
    }
  } catch (e) {
    console.error(`Error with getProof chainId ${chainId}:`, e);
  }

  return [];
}
