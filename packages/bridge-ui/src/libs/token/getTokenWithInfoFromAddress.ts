import { getToken, readContract } from '@wagmi/core';
import type { Address } from 'viem';

import { erc721Abi, erc1155Abi } from '$abi';
import { fetchNFTMetadata } from '$libs/token/fetchNFTMetadata';
import { getLogger } from '$libs/util/logger';
import { safeReadContract } from '$libs/util/safeReadContract';
import { config } from '$libs/wagmi';

import { detectContractType } from './detectContractType';
import { type NFT, type NFTMetadata, type Token, TokenType } from './types';

const log = getLogger('libs:token:getTokenAddresses');

type GetTokenWithInfoFromAddressParams = {
  contractAddress: Address;
  srcChainId: number;
  owner?: Address;
  tokenId?: number;
  type?: TokenType;
};

export const getTokenWithInfoFromAddress = async ({
  contractAddress,
  srcChainId,
  owner,
  tokenId,
  type,
}: GetTokenWithInfoFromAddressParams): Promise<Token | NFT> => {
  log(`getting token info for ${contractAddress} id: ${tokenId}`);
  try {
    const tokenType: TokenType = type ?? (await detectContractType(contractAddress, srcChainId));
    if (tokenType === TokenType.ERC20) {
      return getERC20Info(contractAddress, srcChainId, tokenType);
    } else if (tokenType === TokenType.ERC1155) {
      return getERC1155Info(contractAddress, srcChainId, owner, tokenId, tokenType);
    } else if (tokenType === TokenType.ERC721) {
      return getERC721Info(contractAddress, srcChainId, tokenId, tokenType);
    } else {
      throw new Error('Unsupported token type');
    }
  } catch (err) {
    log('Error getting token info', err);
    throw new Error('Error getting token info');
  }
};

const getERC20Info = async (contractAddress: Address, srcChainId: number, type: TokenType) => {
  log(`getting token info for ERC20`);

  // TODO: check deprecation
  const fetchResult = await getToken(config, {
    address: contractAddress,
    chainId: srcChainId,
  });

  const token = {
    type,
    name: fetchResult.name,
    symbol: fetchResult.symbol,
    addresses: {
      [srcChainId]: contractAddress,
    },
    decimals: fetchResult.decimals,
  } as Token;
  return token;
};

const getERC1155Info = async (
  contractAddress: Address,
  srcChainId: number,
  owner: Address | undefined,
  tokenId: number | undefined,
  type: TokenType,
) => {
  log(`getting token info for ERC1155`);

  const name = await safeReadContract({
    address: contractAddress,
    abi: erc1155Abi,
    functionName: 'name',
    chainId: srcChainId,
  });

  const symbol = await safeReadContract({
    address: contractAddress,
    abi: erc1155Abi,
    functionName: 'symbol',
    chainId: srcChainId,
  });

  let uri = await safeReadContract({
    address: contractAddress,
    abi: erc1155Abi,
    functionName: 'uri',
    chainId: srcChainId,
  });

  if (tokenId !== null && tokenId !== undefined && !uri) {
    uri = await safeReadContract({
      address: contractAddress,
      abi: erc1155Abi,
      functionName: 'uri',
      args: [BigInt(tokenId)],
      chainId: srcChainId,
    });
  }

  let balance;
  if (tokenId !== null && tokenId !== undefined && owner) {
    balance = await readContract(config, {
      address: contractAddress,
      abi: erc1155Abi,
      functionName: 'balanceOf',
      args: [owner, BigInt(tokenId)],
      chainId: srcChainId,
    });
  }

  let token: NFT;
  try {
    token = {
      type,
      symbol,
      name,
      uri,
      addresses: {
        [srcChainId]: contractAddress,
      },
      tokenId: tokenId ?? -1,
      balance: balance ? balance : 0n,
    } as NFT;
    try {
      if (token?.uri) {
        if (!token.metadata) {
          const metadata: NFTMetadata | null = await fetchNFTMetadata(token);
          if (metadata) {
            token.metadata = metadata;
          }
        }
      }
      return token;
    } catch {
      return token;
    }
  } catch (error) {
    log(`error fetching metadata for ${contractAddress} id: ${tokenId}`, error);
  }
  throw new Error('Error getting token info');
};

const getERC721Info = async (
  contractAddress: Address,
  srcChainId: number,
  tokenId: number | undefined,
  type: TokenType,
) => {
  log(`getting token info for ERC721`);

  log(`getting name, symbol and uri for ERC721 token ${contractAddress} id: ${tokenId} on chain ${srcChainId}`);
  const name = await safeReadContract({
    address: contractAddress,
    abi: erc721Abi,
    functionName: 'name',
    chainId: srcChainId,
  });

  const symbol = await safeReadContract({
    address: contractAddress,
    abi: erc721Abi,
    functionName: 'symbol',
    chainId: srcChainId,
  });

  let uri;

  if (tokenId !== null && tokenId !== undefined) {
    uri = await safeReadContract({
      address: contractAddress,
      abi: erc721Abi,
      functionName: 'tokenURI',
      args: [BigInt(tokenId)],
      chainId: srcChainId,
    });
  }

  const token = {
    type,
    addresses: {
      [srcChainId]: contractAddress,
    },
    name,
    symbol,
    tokenId: tokenId ?? 0,
    uri: uri ? uri.toString() : undefined,
  } as NFT;
  try {
    if (token?.uri) {
      if (!token.metadata) {
        const metadata: NFTMetadata | null = await fetchNFTMetadata(token);
        if (metadata) {
          token.metadata = metadata;
        }
      }
    }
    return token;
  } catch {
    return token;
  }
};
