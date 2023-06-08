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

  const _signer = await fetchSigner({ chainId });

  srcChain.set(chain);
  if (chainId === mainnetChain.id) {
    log(`'Switching network to ${mainnetChain.name}`);
    destChain.set(taikoChain);
  } else {
    log(`'Switching network to ${taikoChain.name}`);
    destChain.set(mainnetChain);
  }

  signer.set(_signer);
}
