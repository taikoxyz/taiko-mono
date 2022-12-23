import { BigNumber, Contract, ethers, Signer } from "ethers";
import TokenVault from "../constants/abi/TokenVault";
import type { Chain } from "../domain/chain";
import type { ProcessingFeeMethod } from "../domain/fee";
import type { Token } from "../domain/token";
import { ETH } from "../domain/token";
import { chainIdToTokenVaultAddress } from "../store/bridge";
import { providers } from "../store/providers";
import { get } from "svelte/store";

export const ethGasLimit = 900000;
export const erc20NotDeployedGasLimit = 3100000;
export const erc20DeployedGasLimit = 1100000;

export async function recommendProcessingFee(
  toChain: Chain,
  fromChain: Chain,
  feeType: ProcessingFeeMethod,
  token: Token,
  signer: Signer
): Promise<string> {
  if (!toChain || !fromChain || !token || !signer || !feeType) return "0";
  const p = get(providers);
  const provider = p.get(toChain.id);
  const gasPrice = await provider.getGasPrice();
  // gasLimit for processMessage call for ETH is about ~800k.
  // to make it enticing, we say 900k.
  let gasLimit = ethGasLimit;
  if (token.symbol.toLowerCase() !== ETH.symbol.toLowerCase()) {
    let srcChainAddr = token.addresses.find(
      (t) => t.chainId === fromChain.id
    ).address;

    if (!srcChainAddr || srcChainAddr === "0x00") {
      srcChainAddr = token.addresses.find(
        (t) => t.chainId === toChain.id
      ).address;
    }

    const chainIdsToTokenVault = get(chainIdToTokenVaultAddress);
    const tokenVault = new Contract(
      chainIdsToTokenVault.get(fromChain.id),
      TokenVault,
      signer
    );

    const bridged = await tokenVault.canonicalToBridged(
      toChain.id,
      srcChainAddr
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
