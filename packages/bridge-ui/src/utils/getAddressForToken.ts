import { isETH } from '../token/tokens';
import type { Address, Chain } from '../domain/chain';
import type { Token } from '../domain/token';
import { Contract, Signer } from 'ethers';
import { tokenVaults } from '../vault/tokenVaults';
import { tokenVaultABI } from '../constants/abi';
import { getLogger } from './logger';

const log = getLogger('util:getAddressForToken');

export async function getAddressForToken(
  token: Token,
  fromChain: Chain,
  toChain: Chain,
  signer: Signer,
): Promise<Address> {
  // Get the address for the token on the source chain
  let address = token.addresses.find((t) => t.chainId === fromChain.id).address;

  // If the token isn't ETH or has no address...
  if (!isETH(token) && (!address || address === '0x00')) {
    // Find the address on the destination chain instead
    const destChainAddress = token.addresses.find(
      (t) => t.chainId === toChain.id,
    ).address;

    // Get the token vault contract on the source chain. The idea is to find
    // the bridged address for the token on the destination chain if it's been
    // deployed there. This is registered in the token vault contract,
    // cacnonicalToBridged mapping.
    const srcTokenVaultContract = new Contract(
      tokenVaults[fromChain.id],
      tokenVaultABI,
      signer,
    );

    try {
      const bridgedAdress = await srcTokenVaultContract.canonicalToBridged(
        toChain.id,
        destChainAddress,
      );

      log(`Bridged address for ${token.symbol} is "${bridgedAdress}"`);

      address = bridgedAdress;
    } catch (error) {
      console.error(error);

      throw Error(
        `Failed to get address for ${token.symbol} on chain ${fromChain.id}`,
        {
          cause: error,
        },
      );
    }
  }

  return address;
}
