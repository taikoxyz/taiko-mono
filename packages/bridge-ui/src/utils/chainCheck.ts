import type { Signer } from 'ethers';
import { chains } from '../chain/chains';
import type { ChainID } from '../domain/chain';
import { isOnCorrectChain } from './isOnCorrectChain';
import { switchChainAndSetSigner } from './switchChainAndSetSigner';

export async function chainCheck(
  fromChainId: ChainID,
  toChainId: ChainID,
  currentChainId: ChainID,
  signer: Signer,
) {
  if (currentChainId !== fromChainId) {
    const chain = chains[fromChainId];
    await switchChainAndSetSigner(chain);
  }

  // confirm after switch chain that it worked.
  const correctChain = await isOnCorrectChain(signer, toChainId);
  if (!correctChain) {
    throw Error('You are connected to the wrong chain in your wallet');
  }
}
