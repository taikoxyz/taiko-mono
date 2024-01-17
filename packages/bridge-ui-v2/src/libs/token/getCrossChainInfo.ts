import { type Address, getContract } from '@wagmi/core';
import { type Abi, zeroAddress } from 'viem';

import { erc20VaultABI, erc721VaultABI, erc1155VaultABI } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { getLogger } from '$libs/util/logger';

import { type GetTokenInfo, TokenType } from './types';

const log = getLogger('token:getCrossChainInfo');

export async function getCrossChainInfo({ token, srcChainId, destChainId }: GetTokenInfo) {
  if (token.type === TokenType.ETH) return null; // ETH doesn't have an address

  log(
    `Getting cross chain address for ${token.type} token ${token.symbol} (${token.name}) from chain ${srcChainId} to chain ${destChainId}`,
  );

  const srcChainTokenAddress = Object.values(token.addresses)[0];

  log(`got srcChainTokenAddress',${srcChainTokenAddress} `);
  const vaultABI =
    token.type === TokenType.ERC721
      ? erc721VaultABI
      : token.type === TokenType.ERC1155
        ? erc1155VaultABI
        : erc20VaultABI;

  const vaultAddressKey =
    token.type === TokenType.ERC721
      ? 'erc721VaultAddress'
      : token.type === TokenType.ERC1155
        ? 'erc1155VaultAddress'
        : 'erc20VaultAddress';

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

  let bridgedTokenAddress: Address;
  let bridgedChainId: number;

  // check if the address we have is canonical
  const srcCanonicalTokenInfo = (await srcTokenVaultContract.read.bridgedToCanonical([
    srcChainTokenAddress,
  ])) as Address;
  const srcCanonicalCheck = srcCanonicalTokenInfo[1] as Address;

  const destCanonicalTokenInfo = (await destTokenVaultContract.read.bridgedToCanonical([
    srcChainTokenAddress,
  ])) as Address;
  const destCanonicalCheck = destCanonicalTokenInfo[1] as Address;

  if (srcCanonicalCheck === zeroAddress && destCanonicalCheck === zeroAddress) {
    // if both are zero we are dealing with a canonical address and need to find the bridged one
    bridgedTokenAddress = (await destTokenVaultContract.read.canonicalToBridged([
      BigInt(srcChainId),
      srcChainTokenAddress,
    ])) as Address;
    bridgedChainId = destChainId;

    if (bridgedTokenAddress === zeroAddress) {
      throw new Error(`Could not find any bridged address for ${srcChainTokenAddress}`);
    }
  } else if (destCanonicalCheck !== zeroAddress) {
    // if the destination is not zero, we found a canonical address there
    bridgedTokenAddress = (await destTokenVaultContract.read.canonicalToBridged([
      BigInt(srcChainId),
      destCanonicalCheck,
    ])) as Address;
    bridgedChainId = destChainId;
  } else {
    // if the source is not zero, we found a canonical address there
    bridgedTokenAddress = (await srcTokenVaultContract.read.canonicalToBridged([
      BigInt(destChainId),
      srcCanonicalCheck,
    ])) as Address;
    bridgedChainId = srcChainId;
  }
  log(`Bridged address is ${bridgedTokenAddress} on chain ${bridgedChainId}`);
  return { chainId: bridgedChainId, address: bridgedTokenAddress };
}
