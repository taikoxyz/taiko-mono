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
    if (!tokenInfo) {
      log('No token info found for', token, srcChainId, destChainId);
      throw new NoTokenInfoFoundError(`Could not find any token info`);
    }

    // Pick whichever deployment actually lives on the source chain; the bridged deployment
    // can just as well be on the destination chain, and returning that address here would
    // point every later call at the wrong chain
    if (tokenInfo.canonical?.chainId === srcChainId) {
      address = tokenInfo.canonical.address;
    } else if (tokenInfo.bridged?.chainId === srcChainId) {
      address = tokenInfo.bridged.address;
    }

    if (!address || address === zeroAddress) {
      throw new NoTokenAddressError(`no address found for ${token.symbol} on chain ${srcChainId}`);
    }
  }

  return address;
}
