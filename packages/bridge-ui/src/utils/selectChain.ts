import { switchNetwork } from '@wagmi/core';

import { mainnetChain, taikoChain } from '../chain/chains';
import type { Chain } from '../domain/chain';
import { destChain, srcChain } from '../store/chain';
import { signer } from '../store/signer';
import { getLogger } from '../utils/logger';
import { rpcCall } from './rpcCall';

const log = getLogger('selectChain');

export async function selectChain(chain: Chain) {
  const chainId = chain.id;

  await switchNetwork({ chainId });

  // Requires requesting permission to connect users accounts
  const { provider, returnValue: accounts } = await rpcCall(
    'eth_requestAccounts',
  );

  log('accounts', accounts);

  srcChain.set(chain);
  if (chain.id === mainnetChain.id) {
    destChain.set(taikoChain);
  } else {
    destChain.set(mainnetChain);
  }

  const _signer = provider.getSigner();

  log('signer', _signer);

  signer.set(_signer);
}
