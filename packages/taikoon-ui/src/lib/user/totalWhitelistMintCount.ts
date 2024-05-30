import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import { getAccount } from '@wagmi/core';

import getConfig from '../wagmi/getConfig';
import { whitelist } from '../whitelist';

export async function totalWhitelistMintCount(): Promise<number> {
  const { config, chainId } = getConfig();

  try {
    const account = getAccount(config);
    if (!account.address) return -1;

    const tree = StandardMerkleTree.load(whitelist[chainId]);
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    for (const [_, [address, amount]] of tree.entries()) {
      if (address.toString().toLowerCase() === account.address.toString().toLowerCase()) {
        return amount;
      }
    }
  } catch (e) {
    console.error(`Error with totalWhitelistMintCount chainId ${chainId}:`, e);
  }

  return 0;
}
