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

  const tokenAddress = await getAddress(token, srcChainId, destChainId);

  if (!tokenAddress || tokenAddress === zeroAddress) return null;

  return fetchBalance({
    address: userAddress,
    chainId: srcChainId,
    token: tokenAddress,
  });
}
