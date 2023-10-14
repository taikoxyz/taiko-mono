import { erc721ABI, readContract } from '@wagmi/core';
import type { Address } from 'viem';

import { erc1155ABI } from '$abi';

import { detectContractType } from './detectContractType';
import { TokenType } from './types';

const isOwnerERC1155 = async (
  tokenAddress: Address,
  tokenId: number,
  accountAddress: Address,
  chainId: number,
): Promise<boolean> => {
  try {
    const balance = await readContract({
      address: tokenAddress,
      abi: erc1155ABI,
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
    const owner = await readContract({
      address: tokenAddress,
      abi: erc721ABI,
      functionName: 'ownerOf',
      chainId,
      args: [BigInt(tokenId)],
    });
    return owner === accountAddress;
  } catch (error) {
    return false;
  }
};

export const checkOwnership = async (
  tokenAddress: Address,
  tokenType: TokenType | null,
  tokenIds: number[],
  accountAddress: Address,
  chainId: number,
): Promise<boolean> => {
  if (!tokenType) tokenType = await detectContractType(tokenAddress);
  if (!tokenType || !tokenIds.length || !accountAddress || !chainId) return false;

  const checkPromises = tokenIds.map((tokenId) =>
    tokenType === TokenType.ERC1155
      ? isOwnerERC1155(tokenAddress, tokenId, accountAddress, chainId)
      : tokenType === TokenType.ERC721
      ? isOwnerERC721(tokenAddress, tokenId, accountAddress, chainId)
      : Promise.resolve(false),
  );

  const ownershipResults = await Promise.all(checkPromises);
  return ownershipResults.every((isOwner) => isOwner);
};
