import type { ethers } from 'ethers';

import { chains } from '../chain/chains';
import { tokenVaults } from '../vault/tokenVaults';

export async function isOnCorrectChain(
  signer: ethers.Signer,
  wantChain: number,
) {
  const signerChain = await signer.getChainId();
  if (signerChain !== wantChain) {
    return false;
  }

  const bridgeAddress = chains[wantChain].bridgeAddress;
  const tokenVaultAddress = tokenVaults[wantChain];

  const bridgeAddressCode = await signer.provider.getCode(bridgeAddress);

  const tokenVaultAddressCode = await signer.provider.getCode(
    tokenVaultAddress,
  );

  if (bridgeAddressCode === '0x' || tokenVaultAddressCode === '0x') {
    return false;
  }

  return true;
}
