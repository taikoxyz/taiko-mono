import { type Address, getContract } from '@wagmi/core';
import { type Abi, zeroAddress } from 'viem';

import { erc20VaultABI, erc721VaultABI } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { chains } from '$libs/chain';
import { getLogger } from '$libs/util/logger';

import { type GetCrossChainAddressArgs, TokenType } from './types';

const log = getLogger('token:getCrossChainAddress');

export async function getCrossChainAddress({
  token,
  srcChainId,
  destChainId,
}: GetCrossChainAddressArgs): Promise<Address | null> {
  if (token.type === TokenType.ETH) return null; // ETH doesn't have an address

  log(
    `Getting cross chain address for ${token.type} token ${token.symbol} (${token.name}) from chain ${srcChainId} to chain ${destChainId}`,
  );

  const srcChainTokenAddress = token.addresses[srcChainId];
  const destChainTokenAddress = token.addresses[destChainId];

  const existsOnDestinationChain = destChainTokenAddress && destChainTokenAddress !== zeroAddress;
  const existsOnSourceChain = srcChainTokenAddress && srcChainTokenAddress !== zeroAddress;

  // check if we already have the address
  if (existsOnDestinationChain && existsOnSourceChain) {
    return token.addresses[destChainId];
  }

  const vaultABI = token.type === TokenType.ERC721 ? erc721VaultABI : erc20VaultABI;
  const vaultAddressKey = token.type === TokenType.ERC721 ? 'erc721VaultAddress' : 'erc20VaultAddress';

  // it could be that we don't have the token address on the current chain, but we might it on another chain
  if (!existsOnSourceChain) {
    // find one chain with a configured address
    const configuredChainId = Object.keys(token.addresses).find((chainId) => token.addresses[chainId] !== zeroAddress);

    // if we have no configuration at all, we cannot find the address
    if (!configuredChainId) return null;

    const vaultInfo = await getVaultForToken(token.type, configuredChainId);

    // if we don't have any vault, we cannot find the address
    if (!vaultInfo) return null;

    const { chainId: foundChainId, vaultAddress } = vaultInfo;
    const configuredTokenAddress = token.addresses[Number(configuredChainId)];

    const configuredTokenVaultContract = getContract({
      abi: vaultABI as Abi,
      chainId: foundChainId,
      address: vaultAddress,
    });

    const bridgedAddress = (await configuredTokenVaultContract.read.canonicalToBridged([
      BigInt(configuredChainId),
      configuredTokenAddress,
    ])) as Address;

    return bridgedAddress;
  } else {
    // If we do have an address on the current chain, we need to find the canonical address on the other chain

    const srcTokenVaultContract = getContract({
      abi: vaultABI as Abi,
      chainId: srcChainId,
      address: routingContractsMap[srcChainId][destChainId][vaultAddressKey],
    });

    const destTokenVaultContract = getContract({
      abi: vaultABI as Abi,
      chainId: destChainId,
      address: routingContractsMap[destChainId][srcChainId][vaultAddressKey],
    });

    // first we need to figure out the canonical address of the token
    const canonicalTokenInfo = (await srcTokenVaultContract.read.bridgedToCanonical([srcChainTokenAddress])) as Address;
    const canonicalTokenAddress = canonicalTokenInfo[1]; // this will break if the contracts ever change the order of the return values

    // if the canonical address is 0x0, then the token is canonical
    if (canonicalTokenAddress === zeroAddress) {
      // let's check if it is bridged on the destination chain by querying the destination vault
      // e.g. bridged L1 -> L2 with native L1 token
      return (await destTokenVaultContract.read.canonicalToBridged([
        BigInt(srcChainId),
        srcChainTokenAddress,
      ])) as Address;
    } else {
      // if we have found a canonical, we can check for the bridged address on the source token vault
      // e.g. bridging L2 -> L1 with native L1 token
      return (await srcTokenVaultContract.read.canonicalToBridged([
        BigInt(destChainId),
        canonicalTokenAddress,
      ])) as Address;
    }
  }
}

async function getVaultForToken(tokenType: TokenType, configuredChainId: string) {
  const vaultTypeKey =
    tokenType === TokenType.ERC721
      ? 'erc721VaultAddress'
      : tokenType === TokenType.ERC1155
      ? 'erc1155VaultAddress'
      : 'erc20VaultAddress';

  // we need find a vault that is configured with the selected srcChainId and the configuredChainId
  const vaultInfo = chains
    .filter((chain) => {
      const routesForChain = routingContractsMap[chain.id];
      return (
        routesForChain &&
        routesForChain[Number(configuredChainId)] &&
        routesForChain[Number(configuredChainId)][vaultTypeKey]
      );
    })
    .map((chain) => {
      const vaultAddress = routingContractsMap[chain.id][Number(configuredChainId)][vaultTypeKey];
      return {
        chainId: chain.id,
        vaultAddress,
      };
    });
  return vaultInfo.length > 0 ? vaultInfo[0] : null;
}
