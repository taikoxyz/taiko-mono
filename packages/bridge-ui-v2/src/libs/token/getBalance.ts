import { fetchBalance, type FetchBalanceResult } from '@wagmi/core';
import { type Address, zeroAddress } from 'viem';

import { getLogger } from '$libs/util/logger';

import { getAddress } from './getAddress';
import { type Token, TokenType } from './types';

type GetBalanceArgs = {
  userAddress: Address;
  token?: Token;
  srcChainId?: number;
  destChainId?: number;
};

const log = getLogger('token:getBalance');

export async function getBalance({ userAddress, token, srcChainId, destChainId }: GetBalanceArgs) {
  let tokenBalance: FetchBalanceResult;

  if (!token || token.type === TokenType.ETH) {
    // If no token is passed in, we assume is ETH
    tokenBalance = await fetchBalance({ address: userAddress, chainId: srcChainId });
  } else {
    // We need at least the source chain to find the address
    if (!srcChainId) return;

    // We are dealing with an ERC20 token. We need to first find out its address
    // on the current chain in order to fetch the balance.
    const tokenAddress = await getAddress({ token, srcChainId, destChainId });

    if (!tokenAddress || tokenAddress === zeroAddress) return;

    tokenBalance = await fetchBalance({
      address: userAddress,
      token: tokenAddress,
      chainId: srcChainId,
    });
  }

  log('Token balance', tokenBalance);

  return tokenBalance;
}
