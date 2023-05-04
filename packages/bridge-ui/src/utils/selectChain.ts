import { switchNetwork } from '@wagmi/core';
import { ethers } from 'ethers';
import { fromChain, toChain } from '../store/chain';
import type { Chain } from '../domain/chain';
import { mainnetChain, taikoChain } from '../chain/chains';
import { signer } from '../store/signer';

export async function selectChain(chain: Chain) {
  const chainId = chain.id;

  await switchNetwork({ chainId });

  const provider = new ethers.providers.Web3Provider(
    globalThis.ethereum,
    'any',
  );

  // Triggers the connect request
  await provider.send('eth_requestAccounts', []);

  fromChain.set(chain);
  if (chain.id === mainnetChain.id) {
    toChain.set(taikoChain);
  } else {
    toChain.set(mainnetChain);
  }

  signer.set(provider.getSigner());
}
