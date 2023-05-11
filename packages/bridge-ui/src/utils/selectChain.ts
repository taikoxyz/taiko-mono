import { switchNetwork } from '@wagmi/core';
import { ethers } from 'ethers';
import { fromChain, toChain } from '../store/chain';
import type { Chain } from '../domain/chain';
import { mainnetChain, taikoChain } from '../chain/chains';
import { signer } from '../store/signer';
import { getLogger } from '../utils/logger';

const log = getLogger('util:selectChain');

export async function selectChain(chain: Chain) {
  const chainId = chain.id;

  log('Selecting chain', chain);

  try {
    await switchNetwork({ chainId });
  } catch (error) {
    console.error(error);
    throw new Error('Failed to switch network', { cause: error });
  }

  log('Chain successfully switched');

  const provider = new ethers.providers.Web3Provider(
    globalThis.ethereum,
    'any',
  );

  // Requires requesting permission to connect users accounts
  const accounts = await provider.send('eth_requestAccounts', []);

  log('Accounts', accounts);

  fromChain.set(chain);
  if (chain.id === mainnetChain.id) {
    toChain.set(taikoChain);
  } else {
    toChain.set(mainnetChain);
  }

  const _signer = provider.getSigner();

  log('Signer', _signer);

  signer.set(_signer);
}
