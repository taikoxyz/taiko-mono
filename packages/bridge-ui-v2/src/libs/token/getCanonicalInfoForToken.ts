import { getContract } from '@wagmi/core';
import { type Abi, type Address, zeroAddress } from 'viem';

import { erc20VaultABI, erc721VaultABI, erc1155VaultABI } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { getLogger } from '$libs/util/logger';
import { setCanonicalTokenInfo } from '$stores/canonical';

import { type GetTokenInfo, TokenType } from './types';

const log = getLogger('token:getCanonicalInfoForToken');

export async function getCanonicalInfoForToken({ token, srcChainId, destChainId }: GetTokenInfo) {
  if (token.type === TokenType.ETH) return null; // ETH doesn't have an address

  log(
    `Find canonicalInfo for ${token.type} token ${token.symbol} (${token.name}) from chain ${srcChainId} to chain ${destChainId}`,
  );

  const srcChainTokenAddress = Object.values(token.addresses)[0];
  if (!srcChainTokenAddress) throw new Error('Token has no defined addresses');

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

  let canonicalTokenAddress: Address;
  let canonicalChain: number;

  // check if the address we have is canonical
  const canonicalTokenInfo = (await srcTokenVaultContract.read.bridgedToCanonical([srcChainTokenAddress])) as Address;
  canonicalTokenAddress = canonicalTokenInfo[1] as Address;

  if (canonicalTokenAddress === zeroAddress) {
    // we already have the canonical address
    canonicalTokenAddress = srcChainTokenAddress;
    canonicalChain = srcChainId;
    setCanonicalTokenInfo(canonicalTokenAddress, true, canonicalChain);
    setCanonicalTokenInfo(canonicalTokenInfo[1] as Address, false, destChainId);
  } else {
    // we found a canonical
    canonicalTokenAddress = canonicalTokenInfo[1] as Address;
    canonicalChain = destChainId;
    setCanonicalTokenInfo(canonicalTokenAddress, true, canonicalChain);
    setCanonicalTokenInfo(srcChainTokenAddress, false, srcChainId);
  }

  log(`Found canonical address ${canonicalTokenAddress} on chain ${canonicalChain}`);
  return { chainId: canonicalChain, address: canonicalTokenAddress };
}
