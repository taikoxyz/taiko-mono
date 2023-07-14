import { fetchBalance } from '@wagmi/core';
import type { Address } from 'abitype';
import { zeroAddress } from 'viem';

import { getAddress } from './getAddress';
import { isETH } from './tokens';
import type { Token } from './types';

export async function getBalance(token: Token, userAddress: Address, srcChainId?: number, destChainId?: number) {
  if (isETH(token)) {
    return fetchBalance({ address: userAddress });
  }

  // We are dealing with an ERC20 token. We need to first find out its address
  // on the current chain in order to fetch the balance.
  const tokenAddress = await getAddress(token, srcChainId, destChainId);

  if (!tokenAddress || tokenAddress === zeroAddress) return null;

  // Wagmi is an excellent library 😊
  return fetchBalance({
    address: userAddress,
    chainId: srcChainId,
    token: tokenAddress,
  });
}
