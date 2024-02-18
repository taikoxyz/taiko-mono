import { type Address, zeroAddress } from 'viem';

import { NoTokenAddressError, NoTokenInfoFoundError } from '$libs/error';
import { getLogger } from '$libs/util/logger';

import { getTokenAddresses } from './getTokenAddresses';
import { type Token, TokenType } from './types';

type GetAddressArgs = {
  token: Token;
  srcChainId: number;
  destChainId?: number;
};

const log = getLogger('token:getAddress');

export async function getAddress({ token, srcChainId, destChainId }: GetAddressArgs) {
  if (token.type === TokenType.ETH) return; // ETH doesn't have an address

  // Get the address for the token on the source chain
  let address: Maybe<Address> = token.addresses[srcChainId];

  if (!address || address === zeroAddress) {
    // If we don't have the address yet, let's try to get it from the destination chain
    log('No src address found, fetching bridged one', token, srcChainId, destChainId);

    // We need destination chain to find the address, otherwise
    // there is nothing we can do here.
    if (!destChainId) return;

    const tokenInfo = await getTokenAddresses({ token, srcChainId, destChainId });
    if (!tokenInfo || !tokenInfo.bridged) {
      log('No token info found for', token, srcChainId, destChainId);
      throw new NoTokenInfoFoundError(`Could not find any token info`);
    }
    const { address: bridgedAddress } = tokenInfo.bridged;
    address = bridgedAddress;

    if (!address || address === zeroAddress) {
      throw new NoTokenAddressError(`no address found for ${token.symbol} on chain ${srcChainId}`);
    }
  }

  return address;
}
