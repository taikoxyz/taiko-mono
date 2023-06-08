import { fetchSigner, switchNetwork } from '@wagmi/core';

import { mainnetChain, taikoChain } from '../chain/chains';
import type { Chain } from '../domain/chain';
import { destChain, srcChain } from '../store/chain';
import { signer } from '../store/signer';
import { getLogger } from '../utils/logger';

const log = getLogger('selectChain');

export async function selectChain(chain: Chain) {
  const chainId = chain.id;
  await switchNetwork({ chainId });
}
