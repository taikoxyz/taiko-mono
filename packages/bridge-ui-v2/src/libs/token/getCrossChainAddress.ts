import { type Address, getContract } from '@wagmi/core';

import { tokenVaultABI } from '$abi';
import { chainContractsMap } from '$libs/chain';

import { type Token, TokenType } from './types';

type GetCrossChainAddressArgs = {
  token: Token;
  srcChainId: number;
  destChainId: number;
};

export async function getCrossChainAddress({
  token,
  srcChainId,
  destChainId,
}: GetCrossChainAddressArgs): Promise<Address | null> {
  if (token.type === TokenType.ETH) return null; // ETH doesn't have an address

  const { tokenVaultAddress } = chainContractsMap[destChainId];

  const srcChainTokenAddress = token.addresses[srcChainId];

  // We cannot find the address if we don't have
  // the token address on the source chain
  if (!srcChainTokenAddress) return null;

  const destTokenVaultContract = getContract({
    abi: tokenVaultABI,
    chainId: destChainId,
    address: tokenVaultAddress,
  });

  // Check if the destination token is bridged as well
  const isBridgedToken = await destTokenVaultContract.read.isBridgedToken([srcChainTokenAddress]);

  // if so, we need to get the canonical address from the vault
  if (isBridgedToken) {
    const bridgedToken = await destTokenVaultContract.read.bridgedToCanonical([srcChainTokenAddress]);
    return bridgedToken[1] as Address;
  }

  return destTokenVaultContract.read.canonicalToBridged([BigInt(srcChainId), srcChainTokenAddress]);
}
