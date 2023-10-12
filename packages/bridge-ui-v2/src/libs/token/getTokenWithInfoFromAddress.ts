import { erc721ABI, fetchToken, readContract } from '@wagmi/core';
import type { Address } from 'viem';

import { erc1155ABI } from '$abi';
import { getLogger } from '$libs/util/logger';
import { parseNFTMetadata } from '$libs/util/parseNFTMetadata';
import { safeReadContract } from '$libs/util/safeReadContract';

import { detectContractType } from './detectContractType';
import { type NFT, type Token, TokenType } from './types';

const log = getLogger('libs:token:getTokenInfo');

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
  try {
    const tokenType: TokenType = type ?? (await detectContractType(contractAddress));
    if (tokenType === TokenType.ERC20) {
      return getERC20Info(contractAddress, srcChainId, tokenType);
    } else if (tokenType === TokenType.ERC1155) {
      return getERC1155Info(contractAddress, srcChainId, owner, tokenId, tokenType);
    } else if (tokenType === TokenType.ERC721) {
      const name = await readContract({
        address: contractAddress,
        abi: erc721ABI,
        functionName: 'name',
        chainId: srcChainId,
      });

      const symbol = await readContract({
        address: contractAddress,
        abi: erc721ABI,
        functionName: 'symbol',
        chainId: srcChainId,
      });

      let uri;

      if (tokenId) {
        uri = await safeReadContract({
          address: contractAddress,
          abi: erc721ABI,
          functionName: 'tokenURI',
          args: [BigInt(tokenId)],
          chainId: srcChainId,
        });
      }

      const token = {
        type: tokenType,
        addresses: {
          [srcChainId]: contractAddress,
        },
        name,
        symbol,
        tokenId: tokenId ?? 0,
        uri: uri ? uri.toString() : undefined,
      } as NFT;

      return token;
    } else {
      throw new Error('Unsupported token type');
    }
  } catch (err) {
    log('Error getting token info', err);
    throw new Error('Error getting token info');
  }
};

const getERC20Info = async (contractAddress: Address, srcChainId: number, type: TokenType) => {
  const fetchResult = await fetchToken({
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
  let name = await safeReadContract({
    address: contractAddress,
    abi: erc1155ABI,
    functionName: 'name',
    chainId: srcChainId,
  });

  let uri = await safeReadContract({
    address: contractAddress,
    abi: erc1155ABI,
    functionName: 'uri',
    chainId: srcChainId,
  });
  if (tokenId && !uri)
    uri = await safeReadContract({
      address: contractAddress,
      abi: erc1155ABI,
      functionName: 'uri',
      args: [BigInt(tokenId)],
      chainId: srcChainId,
    });

  let balance;
  if (tokenId && owner) {
    balance = await readContract({
      address: contractAddress,
      abi: erc1155ABI,
      functionName: 'balanceOf',
      args: [owner, BigInt(tokenId)],
      chainId: srcChainId,
    });
  }

  let token: NFT;
  try {
    token = {
      type,
      name: name ? name : 'No collection name',
      uri: uri ? uri.toString() : undefined,
      addresses: {
        [srcChainId]: contractAddress,
      },
      tokenId,
      balance: balance ? balance : 0,
    } as NFT;
    const metadata = await parseNFTMetadata(token);
    if (metadata?.name !== '') name = metadata?.name;
    // todo: more metadata?
    log('logging', token.name, metadata);
    token.metadata = metadata || undefined;
    return token;
  } catch (error) {
    log(`error fetching metadata for ${contractAddress} id: ${tokenId}`, error);
  }
  throw new Error('Error getting token info');
};
