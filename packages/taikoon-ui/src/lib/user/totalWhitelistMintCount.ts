import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import { type Address, getAddress } from 'viem';

import { chainId } from '$lib/chain';

import { whitelist } from '../whitelist';

export async function totalWhitelistMintCount(address: Address): Promise<number> {
  try {
    const tree = StandardMerkleTree.load(whitelist[chainId]);
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    for (const [_, [leafAddress, amount]] of tree.entries()) {
      if (getAddress(leafAddress) === getAddress(address)) {
        return parseInt(amount);
      }
    }
  } catch (e) {
    console.error(`Error with totalWhitelistMintCount chainId ${chainId}:`, e);
  }

  return 0;
}
