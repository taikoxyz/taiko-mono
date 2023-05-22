import { BigNumber, Contract, ethers, Signer } from 'ethers';
import { tokenVaultABI } from '../constants/abi';
import type { Chain } from '../domain/chain';
import type { ProcessingFeeMethod } from '../domain/fee';
import type { Token } from '../domain/token';
import { isETH } from '../token/tokens';
import { providers } from '../provider/providers';
import { tokenVaults } from '../vault/tokenVaults';

export const ethGasLimit = 900000;
export const erc20NotDeployedGasLimit = 3100000;
export const erc20DeployedGasLimit = 1100000;

export async function recommendProcessingFee(
  toChain: Chain,
  fromChain: Chain,
  feeType: ProcessingFeeMethod,
  token: Token,
  signer: Signer,
): Promise<string> {
  if (!toChain || !fromChain || !token || !signer || !feeType) return '0';
  const provider = providers[toChain.id];
  const gasPrice = await provider.getGasPrice();
  // gasLimit for processMessage call for ETH is about ~800k.
  // to make it enticing, we say 900k.
  let gasLimit = ethGasLimit;

  if (!isETH(token)) {
    let srcChainAddr = token.addresses.find(
      (t) => t.chainId === fromChain.id,
    ).address;

    if (!srcChainAddr || srcChainAddr === '0x00') {
      srcChainAddr = token.addresses.find(
        (t) => t.chainId === toChain.id,
      ).address;
    }

    const tokenVault = new Contract(
      tokenVaults[fromChain.id],
      tokenVaultABI,
      signer,
    );

    const bridged = await tokenVault.canonicalToBridged(
      toChain.id,
      srcChainAddr,
    );

    // gas limit for erc20 if not deployed on the dest chain already
    // is about ~2.9m so we add some to make it enticing
    if (bridged == ethers.constants.AddressZero) {
      gasLimit = erc20NotDeployedGasLimit;
    } else {
      // gas limit for erc20 if already deployed on the dest chain is about ~1m
      // so again, add some to ensure processing
      gasLimit = erc20DeployedGasLimit;
    }
  }

  const recommendedFee = BigNumber.from(gasPrice).mul(gasLimit);
  return ethers.utils.formatEther(recommendedFee);
}
