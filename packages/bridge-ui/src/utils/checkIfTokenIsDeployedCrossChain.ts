import { ethers } from 'ethers';
import { ETHToken } from '../token/tokens';
import { tokenVaultABI } from '../constants/abi';
import type { Chain } from '../domain/chain';
import type { Token } from '../domain/token';
import { getLogger } from './logger';

const log = getLogger('util:checkIfTokenIsDeployedCrossChain');

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
      tokenVaultABI,
      provider,
    );

    const tokenAddressOnDestChain = token.addresses.find(
      (a) => a.chainId === toChain.id,
    );

    if (tokenAddressOnDestChain && tokenAddressOnDestChain.address === '0x00') {
      // Check if token is already deployed as BridgedERC20 on destination chain
      const tokenAddressOnSourceChain = token.addresses.find(
        (a) => a.chainId === fromChain.id,
      );

      log(
        'Checking if token',
        token,
        'is deployed as BridgedERC20 on destination chain',
        toChain,
      );

      try {
        const bridgedTokenAddress =
          await destTokenVaultContract.canonicalToBridged(
            fromChain.id,
            tokenAddressOnSourceChain.address,
          );

        log('Address of bridged token:', bridgedTokenAddress);

        if (bridgedTokenAddress !== ethers.constants.AddressZero) {
          return true;
        }
      } catch (error) {
        console.error(error);
        throw new Error('Error checking if token is deployed cross-chain', {
          cause: error,
        });
      }
    }
  }
  return false;
};
