import { getBalance, type GetBalanceReturnType } from '@wagmi/core';
import { type Address, zeroAddress } from 'viem';

import { UnknownTokenTypeError } from '$libs/error';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { getAddress } from './getAddress';
import { type Token, TokenType } from './types';

type GetBalanceArgs = {
  userAddress: Address;
  token?: Token;
  srcChainId?: number;
  destChainId?: number;
};

const log = getLogger('token:getBalance');

export async function fetchBalance({ userAddress, token, srcChainId, destChainId }: GetBalanceArgs) {
  let tokenBalance: GetBalanceReturnType;
  log('getBalance', { userAddress, token, srcChainId, destChainId });
  if (!token || token.type === TokenType.ETH) {
    // If no token is passed in, we assume is ETH
    tokenBalance = await getBalance(config, { address: userAddress, chainId: srcChainId });
  } else if (token.type === TokenType.ERC20) {
    // We need at least the source chain to find the address
    if (!srcChainId) return;

    // We are dealing with an ERC20 token. We need to first find out its address
    // on the current chain in order to fetch the balance.
    const tokenAddress = await getAddress({ token, srcChainId, destChainId });

    if (!tokenAddress || tokenAddress === zeroAddress) return;

    tokenBalance = await getBalance(config, {
      address: userAddress,
      token: tokenAddress,
      chainId: srcChainId,
    });
  } else if (token.type === TokenType.ERC721) {
    tokenBalance = {
      decimals: 0,
      formatted: '0',
      symbol: '',
      value: 0n,
    } as GetBalanceReturnType;
  } else if (token.type === TokenType.ERC1155) {
    tokenBalance = {
      decimals: 0,
      formatted: token.balance?.toString(),
      symbol: '',
      value: token.balance,
    } as GetBalanceReturnType;
  } else {
    throw new UnknownTokenTypeError('Unknown token type');
  }
  log('Token balance', tokenBalance);
  return tokenBalance;
}
