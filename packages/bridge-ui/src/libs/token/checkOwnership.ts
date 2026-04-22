import { readContract } from '@wagmi/core';
import type { Address } from 'viem';

import { erc721Abi, erc1155Abi } from '$abi';
import { config } from '$libs/wagmi';

import { detectContractType } from './detectContractType';
import { type NFT, TokenType } from './types';

export const checkOwnershipOfNFTs = async (nfts: NFT[], accountAddress: Address, chainId: number) => {
  const checkPromises = nfts.map((nft) =>
    checkOwnership(nft.addresses[chainId], nft.type, nft.tokenId, accountAddress, chainId),
  );

  const ownershipResults = await Promise.all(checkPromises);

  // Flatten the arrays of results into a single array
  const flattenedResults = ownershipResults.flat();

  // Separate the results based on the ownership status
  const failedOwnershipChecks = flattenedResults.filter((result) => !result.isOwner);
  const successfulOwnershipChecks = flattenedResults.filter((result) => result.isOwner);

  return {
    allOwned: failedOwnershipChecks.length === 0,
    failedOwnershipChecks,
    successfulOwnershipChecks,
  };
};

export const checkOwnershipOfNFT = async (nft: NFT, accountAddress: Address, chainId: number) => {
  return await checkOwnership(nft.addresses[chainId], nft.type, nft.tokenId, accountAddress, chainId);
};

export const checkOwnership = async (
  tokenAddress: Address,
  tokenType: TokenType | null,
  tokenIds: number[] | number,
  accountAddress: Address,
  chainId: number,
): Promise<{ tokenId: number; isOwner: boolean }[]> => {
  if (!tokenType) tokenType = await detectContractType(tokenAddress, chainId);
  if (
    !tokenType ||
    tokenIds === undefined ||
    tokenIds === null ||
    (Array.isArray(tokenIds) && tokenIds.length === 0) ||
    !accountAddress ||
    !chainId
  )
    return [];

  if (Array.isArray(tokenIds)) {
    const checkPromises = tokenIds.map(async (tokenId) => {
      const isOwner = await determineOwnership(tokenType!, tokenAddress, tokenId, accountAddress, chainId);
      return { tokenId, isOwner };
    });

    return await Promise.all(checkPromises);
  } else {
    const checkOwnershipForTokenId = async (tokenId: number) => {
      const isOwner = await determineOwnership(tokenType!, tokenAddress, tokenId, accountAddress, chainId);
      return { tokenId, isOwner };
    };
    const result = await checkOwnershipForTokenId(tokenIds);
    return [result];
  }
};

const determineOwnership = async (
  tokenType: TokenType,
  tokenAddress: Address,
  tokenId: number,
  accountAddress: Address,
  chainId: number,
) => {
  return tokenType === TokenType.ERC1155
    ? isOwnerERC1155(tokenAddress, tokenId, accountAddress, chainId)
    : tokenType === TokenType.ERC721
      ? isOwnerERC721(tokenAddress, tokenId, accountAddress, chainId)
      : Promise.resolve(false);
};

const isOwnerERC1155 = async (
  tokenAddress: Address,
  tokenId: number,
  accountAddress: Address,
  chainId: number,
): Promise<boolean> => {
  try {
    const balance = await readContract(config, {
      address: tokenAddress,
      abi: erc1155Abi,
      functionName: 'balanceOf',
      chainId,
      args: [accountAddress, BigInt(tokenId)],
    });

    return Number(balance) > 0;
  } catch (error) {
    return false;
  }
};

const isOwnerERC721 = async (
  tokenAddress: Address,
  tokenId: number,
  accountAddress: Address,
  chainId: number,
): Promise<boolean> => {
  try {
    const owner = await readContract(config, {
      address: tokenAddress,
      abi: erc721Abi,
      functionName: 'ownerOf',
      chainId,
      args: [BigInt(tokenId)],
    });

    return owner === accountAddress;
  } catch (error) {
    return false;
  }
};
