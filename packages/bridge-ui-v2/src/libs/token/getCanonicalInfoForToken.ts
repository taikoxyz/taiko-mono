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

  const destTokenVaultContract = getContract({
    abi: vaultABI as Abi,
    chainId: destChainId,
    address: routingContractsMap[destChainId][srcChainId][vaultAddressKey],
  });

  let canonicalTokenAddress: Address;
  let canonicalChain: number;

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
    // if both are zero we are dealing with a canonical address
    canonicalTokenAddress = srcChainTokenAddress;
    canonicalChain = srcChainId;
  } else if (destCanonicalCheck !== zeroAddress) {
    // if the destination is not zero, we found a canonical address there
    canonicalTokenAddress = destCanonicalCheck;
    canonicalChain = srcChainId;
  } else {
    // if the source is not zero, we found a canonical address there
    canonicalTokenAddress = srcCanonicalCheck;
    canonicalChain = destChainId;
  }
  setCanonicalTokenInfo(canonicalTokenAddress, true, canonicalChain);

  log(`Found canonical address ${canonicalTokenAddress} on chain ${canonicalChain}`);
  return { chainId: canonicalChain, address: canonicalTokenAddress };
}
