import { getContract } from '@wagmi/core';

import { tokenVaultABI } from '$abi';
import { chainContractsMap } from '$libs/chain';

import { isETH } from './tokens';
import type { Token } from './types';

type GetCrossChainAddressArgs = {
  token: Token;
  srcChainId: number;
  destChainId: number;
};

export function getCrossChainAddress({ token, srcChainId, destChainId }: GetCrossChainAddressArgs) {
  if (isETH(token)) return; // ETH doesn't have an address

  const { tokenVaultAddress } = chainContractsMap[destChainId];

  const srcChainTokenAddress = token.addresses[srcChainId];

  // We cannot find the address if we don't have
  // the token address on the source chain
  if (!srcChainTokenAddress) return;

  const destTokenVaultContract = getContract({
    abi: tokenVaultABI,
    chainId: destChainId,
    address: tokenVaultAddress,
  });

  return destTokenVaultContract.read.canonicalToBridged([BigInt(srcChainId), srcChainTokenAddress]);
}
