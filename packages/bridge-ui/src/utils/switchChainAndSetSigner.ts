import { fetchSigner, switchNetwork } from '@wagmi/core';
import { ethers } from 'ethers';
import { fromChain, toChain } from '../store/chain';
import type { Chain } from '../domain/chain';
import { mainnetChain, taikoChain } from '../chain/chains';
import { signer } from '../store/signer';

export async function switchChainAndSetSigner(chain: Chain) {
  const chainId = chain.id;

  await switchNetwork({ chainId });

  const provider = new ethers.providers.Web3Provider(globalThis.ethereum);
  await provider.send('eth_requestAccounts', []);

  fromChain.set(chain);
  if (chain.id === mainnetChain.id) {
    toChain.set(taikoChain);
  } else {
    toChain.set(mainnetChain);
  }

  const wagmiSigner = await fetchSigner({ chainId });

  signer.set(wagmiSigner);
}
