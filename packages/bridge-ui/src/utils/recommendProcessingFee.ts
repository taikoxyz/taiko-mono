import { BigNumber, Contract, ethers, Signer } from 'ethers';

import { tokenVaultABI } from '../constants/abi';
import type { Chain } from '../domain/chain';
import type { ProcessingFeeMethod } from '../domain/fee';
import type { Token } from '../domain/token';
import { providers } from '../provider/providers';
import { isETH } from '../token/tokens';
import { tokenVaults } from '../vault/tokenVaults';

// TODO: config these
export const ethGasLimit = 900000;
export const erc20NotDeployedGasLimit = 3100000;
export const erc20DeployedGasLimit = 1100000;

export async function recommendProcessingFee(
  destChain: Chain,
  srcChain: Chain,
  feeType: ProcessingFeeMethod,
  token: Token,
  signer: Signer,
): Promise<string> {
  if (!destChain || !srcChain || !token || !signer || !feeType) return '0';

  const destProvider = providers[destChain.id];
  const gasPrice = await destProvider.getGasPrice();

  // gasLimit for processMessage call for ETH is about ~800k.
  // to make it enticing, we say 900k.
  let gasLimit = ethGasLimit;

  if (!isETH(token)) {
    let srcChainAddr = token.addresses[srcChain.id];

    if (!srcChainAddr || srcChainAddr === '0x00') {
      srcChainAddr = token.addresses[destChain.id];
    }

    const srcTokenVault = new Contract(
      tokenVaults[srcChain.id],
      tokenVaultABI,
      signer,
    );

    try {
      const bridged = await srcTokenVault.canonicalToBridged(
        destChain.id,
        srcChainAddr,
      );

      // Gas limit for erc20 if not deployed on the dest chain already
      // is about ~2.9m so we add some to make it enticing
      if (bridged == ethers.constants.AddressZero) {
        gasLimit = erc20NotDeployedGasLimit;
      } else {
        // Gas limit for erc20 if already deployed on the dest chain is about ~1m
        // so again, add some to ensure processing
        gasLimit = erc20DeployedGasLimit;
      }
    } catch (error) {
      console.error(error);
      throw new Error('failed to get bridged address', { cause: error });
    }
  }

  const recommendedFee = BigNumber.from(gasPrice).mul(gasLimit);

  return ethers.utils.formatEther(recommendedFee);
}
