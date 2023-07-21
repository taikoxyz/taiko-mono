import { type Address, zeroAddress } from 'viem';

import { getLogger } from '$libs/util/logger';

import { getCrossChainAddress } from './getCrossChainAddress';
import { isETH } from './tokens';
import type { Token } from './types';

type GetAddressArgs = {
  token: Token;
  srcChainId: number;
  destChainId?: number;
};

const log = getLogger('token:getAddress');

export async function getAddress({ token, srcChainId, destChainId }: GetAddressArgs) {
  if (isETH(token)) return; // ETH doesn't have an address

  // Get the address for the token on the source chain
  let address: Maybe<Address> = token.addresses[srcChainId];

  if (!address || address === zeroAddress) {
    // We need destination chain to find the address, otherwise
    // there is nothing we can do here.
    if (!destChainId) return;

    // Find the address on the destination chain instead. We are
    // most likely on Taiko chain. We need to then query the
    // canonicalToBridged mapping on the other chain
    address = await getCrossChainAddress({
      token,
      srcChainId: destChainId,
      destChainId: srcChainId,
    });

    log(`Bridged address for ${token.symbol} is "${address}"`);
  }

  return address;
}
