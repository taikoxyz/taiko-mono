import { switchNetwork } from '@wagmi/core';
import { ethers } from 'ethers';
import { fromChain, toChain } from '../store/chain';
import type { Chain } from '../domain/chain';
import { mainnetChain, taikoChain } from '../chain/chains';
import { signer } from '../store/signer';
import { getLogger } from '../utils/logger';

const log = getLogger('selectChain');

export async function selectChain(chain: Chain, updateSigner = false) {
  const chainId = chain.id;

  await switchNetwork({ chainId });

  const provider = new ethers.providers.Web3Provider(
    globalThis.ethereum,
    'any',
  );

  // Requires requesting permission to connect users accounts
  const accounts = await provider.send('eth_requestAccounts', []);

  log('accounts', accounts);

  fromChain.set(chain);
  if (chain.id === mainnetChain.id) {
    toChain.set(taikoChain);
  } else {
    toChain.set(mainnetChain);
  }

  // This might not be required as we are watching for changes
  // in the account, in which case we will set the signer there
  // if there is any change. That's why the default value of
  // updateSigner is false
  if (updateSigner) {
    const _signer = provider.getSigner();

    log('signer', _signer);

    signer.set(_signer);
  }
}
