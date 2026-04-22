import { totalWhitelistMintCount } from '$lib/user/totalWhitelistMintCount';

import { canMint } from './canMint';

export async function hasMinted(): Promise<boolean> {
  try {
    const mintPossible = await canMint();
    const whitelistMints = await totalWhitelistMintCount();

    return !mintPossible && whitelistMints > 0;
  } catch (e) {
    console.warn(e);
    return false;
  }
}
