import { Contract, Signer } from 'ethers';
import type { Address } from 'wagmi';

import { tokenVaultABI } from '../constants/abi';
import type { Chain } from '../domain/chain';
import type { Token } from '../domain/token';
import { isETH } from '../token/tokens';
import { tokenVaults } from '../vault/tokenVaults';
import { getLogger } from './logger';

const log = getLogger('util:getAddressForToken');

export async function getAddressForToken(
  token: Token,
  srcChain: Chain,
  destChain: Chain,
  signer: Signer,
): Promise<Address> {
  // Get the address for the token on the source chain
  let address = token.addresses[srcChain.id];

  // If the token isn't ETH or has no address...
  if (!isETH(token) && (!address || address === '0x00')) {
    // Find the address on the destination chain instead
    const destChainAddress = token.addresses[destChain.id];

    // Get the token vault contract on the source chain. The idea is to find
    // the bridged address for the token on the destination chain if it's been
    // deployed there. This is registered in the token vault contract,
    // cacnonicalToBridged mapping.
    const srcTokenVaultContract = new Contract(
      tokenVaults[srcChain.id],
      tokenVaultABI,
      signer,
    );

    try {
      const bridgedAdress = await srcTokenVaultContract.canonicalToBridged(
        destChain.id,
        destChainAddress,
      );

      log(`Bridged address for ${token.symbol} is "${bridgedAdress}"`);

      address = bridgedAdress;
    } catch (error) {
      console.error(error);

      throw Error(
        `Failed to get address for ${token.symbol} on chain ${srcChain.id}`,
        {
          cause: error,
        },
      );
    }
  }

  return address;
}
