import { fetchBalance, type FetchBalanceResult } from '@wagmi/core';
import type { Address } from 'abitype';
import { zeroAddress } from 'viem';

import { getLogger } from '$libs/util/logger';

import { getAddress } from './getAddress';
import { isETH } from './tokens';
import type { Token } from './types';

type GetBalanceArgs = {
  token: Token;
  userAddress: Address;
  srcChainId?: number;
  destChainId?: number;
};

const log = getLogger('token:getBalance');

export async function getBalance({ token, userAddress, srcChainId, destChainId }: GetBalanceArgs) {
  let tokenBalance: FetchBalanceResult | null = null;

  if (isETH(token)) {
    tokenBalance = await fetchBalance({ address: userAddress });
  } else {
    // We are dealing with an ERC20 token. We need to first find out its address
    // on the current chain in order to fetch the balance.
    const tokenAddress = await getAddress({ token, srcChainId, destChainId });

    if (!tokenAddress || tokenAddress === zeroAddress) return null;

    // Wagmi is an excellent library 😊
    tokenBalance = await fetchBalance({
      address: userAddress,
      chainId: srcChainId,
      token: tokenAddress,
    });
  }

  log('Token balance', tokenBalance);

  return tokenBalance;
}
