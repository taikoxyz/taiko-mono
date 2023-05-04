import { ethers } from 'ethers';
import { ETHToken } from '../token/tokens';
import TokenVault from '../constants/abi/TokenVault.json';
import type { Chain } from '../domain/chain';
import type { Token } from '../domain/token';

export const checkIfTokenIsDeployedCrossChain = async (
  token: Token,
  provider: ethers.providers.StaticJsonRpcProvider,
  destTokenVaultAddress: string,
  toChain: Chain,
  fromChain: Chain,
): Promise<boolean> => {
  if (token.symbol !== ETHToken.symbol) {
    const destTokenVaultContract = new ethers.Contract(
      destTokenVaultAddress,
      TokenVault,
      provider,
    );
    const tokenAddressOnDestChain = token.addresses.find(
      (a) => a.chainId === toChain.id,
    );
    if (tokenAddressOnDestChain && tokenAddressOnDestChain.address === '0x00') {
      // check if token is already deployed as BridgedERC20 on destination chain
      const tokenAddressOnSourceChain = token.addresses.find(
        (a) => a.chainId === fromChain.id,
      );
      const bridgedTokenAddress =
        await destTokenVaultContract.canonicalToBridged(
          fromChain.id,
          tokenAddressOnSourceChain.address,
        );
      if (bridgedTokenAddress !== ethers.constants.AddressZero) {
        return true;
      }
    }
  }
  return false;
};
