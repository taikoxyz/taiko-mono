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

  // `signer.provider.getCode(address: string): Promise<string>)`
  // Returns the contract code of address as of the blockTag block height.
  // If there is no contract currently deployed, the result is '0x'
  // See: https://docs.ethers.org/v5/api/providers/provider/#Provider-getCode

  const bridgeAddressCode = await signer.provider.getCode(bridgeAddress);

  const tokenVaultAddressCode = await signer.provider.getCode(
    tokenVaultAddress,
  );

  if (bridgeAddressCode === '0x' || tokenVaultAddressCode === '0x') {
    return false;
  }

  return true;
}
