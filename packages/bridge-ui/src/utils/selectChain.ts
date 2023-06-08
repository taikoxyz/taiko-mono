import { fetchSigner, switchNetwork } from '@wagmi/core';

import type { Chain } from '../domain/chain';
import { signer } from '../store/signer';

export async function selectChain(chain: Chain) {
  const chainId = chain.id;

  await switchNetwork({ chainId });

  // We're watching of network changes, so we don't need to manually set the chain.

  const _signer = await fetchSigner();

  signer.set(_signer);
}
