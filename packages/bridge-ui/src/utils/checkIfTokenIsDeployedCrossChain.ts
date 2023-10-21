import { ethers } from 'ethers';

import { tokenVaultABI } from '../constants/abi';
import type { Chain } from '../domain/chain';
import type { Token } from '../domain/token';
import { isETH } from '../token/tokens';
import { getLogger } from './logger';

const log = getLogger('util:checkIfTokenIsDeployedCrossChain');

export const checkIfTokenIsDeployedCrossChain = async (
  token: Token,
  provider: ethers.providers.StaticJsonRpcProvider,
  destTokenVaultAddress: string,
  destChain: Chain,
  srcChain: Chain,
): Promise<boolean> => {
  if (!isETH(token)) {
    const destTokenVaultContract = new ethers.Contract(
      destTokenVaultAddress,
      tokenVaultABI,
      provider,
    );

    const tokenAddressOnDestChain = token.addresses[destChain.id];

    if (tokenAddressOnDestChain !== '0x00') {
      return true;
    }

    // Check if token is already deployed as BridgedERC20 on destination chain
    const tokenAddressOnSourceChain = token.addresses[srcChain.id];

    log(
      'Checking if token',
      token,
      'is deployed as BridgedERC20 on destination chain',
      destChain,
    );

    try {
      const isBridgedToken = await destTokenVaultContract.isBridgedToken(
        tokenAddressOnSourceChain,
      );

      if (isBridgedToken) {
        return await destTokenVaultContract.bridgedToCanonical(
          srcChain.id,
          tokenAddressOnSourceChain,
        );
      } else {
        const bridgedTokenAddress =
          await destTokenVaultContract.canonicalToBridged(
            srcChain.id,
            tokenAddressOnSourceChain,
          );

        return bridgedTokenAddress !== ethers.constants.AddressZero;
      }
    } catch (error) {
      console.error(error);
      throw new Error(
        'encountered an issue when checking if token is deployed cross-chain',
        {
          cause: error,
        },
      );
    }
  }
  return false;
};
