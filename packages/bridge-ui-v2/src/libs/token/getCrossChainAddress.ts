import { type Address, getContract } from '@wagmi/core';
import { zeroAddress } from 'viem';

import { tokenVaultABI } from '$abi';
import { chainContractsMap } from '$libs/chain';

import { type GetCrossChainAddressArgs, TokenType } from './types';

export async function getCrossChainAddress({
  token,
  srcChainId,
  destChainId,
}: GetCrossChainAddressArgs): Promise<Address | null> {
  if (token.type === TokenType.ETH) return null; // ETH doesn't have an address

  const srcChainTokenAddress = token.addresses[srcChainId];
  const destChainTokenAddress = token.addresses[destChainId];

  // check if we already have it
  if (destChainTokenAddress && destChainTokenAddress !== zeroAddress) {
    return token.addresses[destChainId];
  }

  // We cannot find the address if we don't have
  // the token address on the source chain
  if (!srcChainId) return null;

  const { tokenVaultAddress: srcChainTokenVaultAddress } = chainContractsMap[srcChainId];
  const { tokenVaultAddress: destChainTokenVaultAddress } = chainContractsMap[destChainId];

  const srcTokenVaultContract = getContract({
    abi: tokenVaultABI,
    chainId: srcChainId,
    address: srcChainTokenVaultAddress,
  });

  const destTokenVaultContract = getContract({
    abi: tokenVaultABI,
    chainId: destChainId,
    address: destChainTokenVaultAddress,
  });

  // first we need to figure out the canonical address of the token
  const canonicalTokenInfo = await srcTokenVaultContract.read.bridgedToCanonical([srcChainTokenAddress]);
  const canonicalTokenAddress = canonicalTokenInfo[1]; // this will break if the contracts ever change the order of the return values

  // if the canonical address is 0x0, then the token is canonical
  if (canonicalTokenAddress === zeroAddress) {
    // let's check if it is bridged on the destination chain by querying the destination vault
    // e.g. bridged L1 -> L2 with native L1 token
    return await destTokenVaultContract.read.canonicalToBridged([BigInt(srcChainId), srcChainTokenAddress]);
  } else {
    // if we have found a canonical, we can check for the bridged address on the source token vault
    // e.g. bridging L2 -> L1 with native L1 token
    return await srcTokenVaultContract.read.canonicalToBridged([BigInt(destChainId), canonicalTokenAddress]);
  }
}
