import { type Address, getContract } from '@wagmi/core';
import { zeroAddress } from 'viem';

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

  let crossChainAddress: Address;

  const { tokenVaultAddress: srcChainTokenVaultAddress } = chainContractsMap[srcChainId];

  const srcChainTokenAddress = token.addresses[srcChainId];

  // We cannot find the address if we don't have
  // the token address on the source chain
  if (!srcChainTokenAddress) return null;

  const srcTokenVaultContract = getContract({
    abi: tokenVaultABI,
    chainId: srcChainId,
    address: srcChainTokenVaultAddress,
  });

  // first we need to get the canonical address of the token 
  const canonicalTokenInfo = await srcTokenVaultContract.read.bridgedToCanonical([srcChainTokenAddress]);
  const canonicalTokenAddress = canonicalTokenInfo[1]; // this will break if the contracts ever change the order of the return values

  // if the canonical address is 0x0, then the token is canonical
  if (canonicalTokenAddress === zeroAddress) {
    // let's check if it is bridged on the destination chain
    crossChainAddress = await srcTokenVaultContract.read.canonicalToBridged([BigInt(destChainId), srcChainTokenAddress])
  } else {
    // if we have a canonical, we get the bridged address on the destination chain by using this instead
    crossChainAddress = await srcTokenVaultContract.read.canonicalToBridged([BigInt(destChainId), canonicalTokenAddress])
  }

  return crossChainAddress;
}
