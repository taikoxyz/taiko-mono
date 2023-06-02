import { switchNetwork } from '@wagmi/core';
import { ethers } from 'ethers';

import { mainnetChain, taikoChain } from '../chain/chains';
import type { Chain } from '../domain/chain';
import { destChain,srcChain } from '../store/chain';
import { signer } from '../store/signer';
import { getLogger } from '../utils/logger';

const log = getLogger('selectChain');

export async function selectChain(chain: Chain) {
  const chainId = chain.id;

  await switchNetwork({ chainId });

  const provider = new ethers.providers.Web3Provider(
    globalThis.ethereum,
    'any',
  );

  // Requires requesting permission to connect users accounts
  const accounts = await provider.send('eth_requestAccounts', []);

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
