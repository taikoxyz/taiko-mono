import { type Address, getContract } from '@wagmi/core';
import { zeroAddress } from 'viem';

import { erc20VaultABI } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { chains } from '$libs/chain';
import { getLogger } from '$libs/util/logger';

import { type GetCrossChainAddressArgs, TokenType } from './types';

const log = getLogger('token:getCrossChainAddress');

// TODO: have another look at this function

export async function getCrossChainAddress({
  token,
  srcChainId,
  destChainId,
}: GetCrossChainAddressArgs): Promise<Address | null> {
  if (token.type === TokenType.ETH) return null; // ETH doesn't have an address
  log(
    `Getting cross chain address for token ${token.symbol} (${token.name}) from chain ${srcChainId} to chain ${destChainId}`,
  );

  if (token.type === TokenType.ERC721) return null; // TODO
  if (token.type === TokenType.ERC1155) return null; // TODO

  const srcChainTokenAddress = token.addresses[srcChainId];
  const destChainTokenAddress = token.addresses[destChainId];

  const existsOnDestinationChain = destChainTokenAddress && destChainTokenAddress !== zeroAddress;
  const existsOnSourceChain = srcChainTokenAddress && srcChainTokenAddress !== zeroAddress;

  // check if we already have it but only if we have it on the current chain as well
  if (existsOnDestinationChain && existsOnSourceChain) {
    return token.addresses[destChainId];
  }

  // it could be that we don't have the token address on the current chain, but we have it on another chain
  if (!existsOnSourceChain) {
    // find one chain with a configured address
    const configuredChainId = Object.keys(token.addresses).find((chainId) => token.addresses[chainId] !== zeroAddress);

    // if we have no configuration at all, we cannot find the address
    if (!configuredChainId) return null;

    // get the configured token address on that chain
    const configuredTokenAddress = token.addresses[Number(configuredChainId)];

    // we need find a vault that is configured with the selected srcChainId and the configuredChainId
    const erc20VaultInfo = chains
      .filter((chain) => {
        const routesForChain = routingContractsMap[chain.id];
        return (
          routesForChain &&
          routesForChain[Number(configuredChainId)] &&
          routesForChain[Number(configuredChainId)].erc20VaultAddress
        );
      })
      .map((chain) => {
        const erc20VaultAddress = routingContractsMap[chain.id][Number(configuredChainId)].erc20VaultAddress;
        return {
          chainId: chain.id,
          vaultAddress: erc20VaultAddress,
        };
      });

    // if we don't have any vault, we cannot find the address
    if (erc20VaultInfo.length === 0) return null;

    // use the first one we find
    const { chainId: foundChainId, vaultAddress: erc20VaultAddress } = erc20VaultInfo[0];

    const configuredTokenVaultContract = getContract({
      abi: erc20VaultABI,
      chainId: foundChainId,
      address: erc20VaultAddress,
    });

    const bridgedAddress = await configuredTokenVaultContract.read.canonicalToBridged([
      BigInt(configuredChainId),
      configuredTokenAddress,
    ]);

    return bridgedAddress;

    // now that we have the bridgedAddress address, we can check if it is bridged
    // const { erc20VaultAddress: destChainTokenVaultAddress } =
    //   routingContractsMap[destChainId][foundChainId];
    // const destTokenVaultContract = getContract({
    //   abi: erc20VaultABI,
    //   chainId: destChainId,
    //   address: destChainTokenVaultAddress,
    // });

    // return await destTokenVaultContract.read.canonicalToBridged([BigInt(destChainId), bridgedAddress]);
  } else {
    const { erc20VaultAddress: srcChainTokenVaultAddress } = routingContractsMap[srcChainId][destChainId];
    const { erc20VaultAddress: destChainTokenVaultAddress } = routingContractsMap[destChainId][srcChainId];

    const srcTokenVaultContract = getContract({
      abi: erc20VaultABI,
      chainId: srcChainId,
      address: srcChainTokenVaultAddress,
    });

    const destTokenVaultContract = getContract({
      abi: erc20VaultABI,
      chainId: destChainId,
      address: destChainTokenVaultAddress,
    });

    // first we need to figure out the canonical address of the token
    const canonicalTokenInfo = await srcTokenVaultContract.read.bridgedToCanonical([srcChainTokenAddress]);
    const canonicalTokenAddress = canonicalTokenInfo[1]; // this will break if the contracts ever change the order of the return values

    // if the canonical address is 0x0, then the token is canonical
    if (canonicalTokenAddress === zeroAddress) {
      // let's check if it is bridged on the destination chain by querying the destination vault
      // e.g. bridged L1 -> L2 with native L1 token
      return await destTokenVaultContract.read.canonicalToBridged([BigInt(srcChainId), srcChainTokenAddress]);
    } else {
      // if we have found a canonical, we can check for the bridged address on the source token vault
      // e.g. bridging L2 -> L1 with native L1 token
      return await srcTokenVaultContract.read.canonicalToBridged([BigInt(destChainId), canonicalTokenAddress]);
    }
  }
}
