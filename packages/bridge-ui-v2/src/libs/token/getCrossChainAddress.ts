import { type Address, getContract } from '@wagmi/core';
import { zeroAddress } from 'viem';

import { tokenVaultABI } from '$abi';
import { chainContractsMap } from '$libs/chain';
import { getLogger } from '$libs/util/logger';

import { type GetCrossChainAddressArgs, TokenType } from './types';

const log = getLogger('token:getCrossChainAddress');

export async function getCrossChainAddress({
  token,
  srcChainId,
  destChainId,
}: GetCrossChainAddressArgs): Promise<Address | null> {
  if (token.type === TokenType.ETH) return null; // ETH doesn't have an address

  log(
    `Getting cross chain address for token ${token.symbol} (${token.name}) from chain ${srcChainId} to chain ${destChainId}`,
  );
  const srcChainTokenAddress = token.addresses[srcChainId];
  const destChainTokenAddress = token.addresses[destChainId];

  // check if we already have it
  if (destChainTokenAddress && destChainTokenAddress !== zeroAddress) {
    return token.addresses[destChainId];
  }

  if (!srcChainTokenAddress || srcChainTokenAddress === zeroAddress) {
    throw new Error(
      `Token ${token.symbol} (${token.name}) does not have any valid configured address on chain ${srcChainId} or ${destChainId}`,
    );
  }

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
