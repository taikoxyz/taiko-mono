import type { Signer } from 'ethers';
import { chains } from '../chain/chains';
import type { ChainID } from '../domain/chain';
import { isOnCorrectChain } from './isOnCorrectChain';
import { switchChainAndSetSigner } from './switchChainAndSetSigner';

export async function chainCheck(
  currentChainId: ChainID,
  destChainId: ChainID,
  signer: Signer,
) {
  if (currentChainId !== destChainId) {
    const chain = chains[destChainId];
    await switchChainAndSetSigner(chain);
  }

  // confirm after switch chain that it worked.
  const correctChain = await isOnCorrectChain(signer, destChainId);
  if (!correctChain) {
    throw Error('You are connected to the wrong chain in your wallet');
  }
}
