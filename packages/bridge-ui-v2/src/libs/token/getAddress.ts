import { getContract } from '@wagmi/core';
import { zeroAddress } from 'viem';

import { tokenVaultABI } from '$abi';
import { chainContractsMap } from '$libs/chain';
import { getLogger } from '$libs/util/logger';

import { isETH } from './tokens';
import type { Token } from './types';

type GetAddressArgs = {
  token: Token;
  chainId?: number;
  destChainId?: number;
};

const log = getLogger('token:getAddress');

export async function getAddress({ token, chainId, destChainId }: GetAddressArgs) {
  if (!chainId) return;

  // Get the address for the token on the source chain
  let address = token.addresses[chainId];

  // If the token isn't ETH and has no address...
  if (!isETH(token) && (!address || address === zeroAddress)) {
    if (!destChainId) return;

    // Find the address on the destination chain instead. We are
    // most likely on Taiko chain and the token hasn't yet been
    // deployed on it.
    const destChainTokenAddress = token.addresses[destChainId];

    // Get the TokenVault contract on the source chain. The idea is to find
    // the bridged address for the token on the destination chain if it's been
    // deployed there. This is registered in the TokenVault contract,
    // cacnonicalToBridged mapping.
    const srcTokenVaultContract = getContract({
      abi: tokenVaultABI,
      address: chainContractsMap[chainId].tokenVaultAddress,
    });

    address = await srcTokenVaultContract.read.canonicalToBridged([BigInt(destChainId), destChainTokenAddress]);

    log(`Bridged address for ${token.symbol} is "${address}"`);
  }

  return address;
}
