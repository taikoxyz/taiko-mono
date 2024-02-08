import { erc721ABI, fetchToken, readContracts } from '@wagmi/core';
import type { Address } from 'viem';

import { erc1155ABI } from '$abi';
import { fetchNFTMetadata } from '$libs/token/fetchNFTMetadata';
import { getLogger } from '$libs/util/logger';
import { safeReadContract } from '$libs/util/safeReadContract';

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
  log(`getting token info for ERC1155`);

  const tokenContract = {
    address: contractAddress,
    chainId: srcChainId,
    abi: erc1155ABI,
  } as const;

  if (!tokenId) throw new Error('tokenId is required');
  let balance;
  let name = 'No collection name';
  let uri = '';
  let symbol = '';

  if (tokenId !== null && tokenId !== undefined && owner) {
    const result = await readContracts({
      contracts: [
        {
          ...tokenContract,
          args: [BigInt(tokenId)],
          functionName: 'uri',
        },
        {
          ...tokenContract,
          functionName: 'name',
        },
        {
          ...tokenContract,
          functionName: 'balanceOf',
          args: [owner, BigInt(tokenId)],
        },
        {
          ...tokenContract,
          functionName: 'symbol',
        },
      ],
      allowFailure: true,
    });
    uri = result[0].result ? result[0].result.toString() : '';
    name = result[1].result ? result[1].result.toString() : '';
    balance = result[2].result ? result[2].result : 0;
    symbol = result[3].result ? result[3].result.toString() : '';
  } else if (tokenId !== null && tokenId !== undefined && !owner) {
    const result = await readContracts({
      contracts: [
        {
          ...tokenContract,
          args: [BigInt(tokenId)],
          functionName: 'uri',
        },
        {
          ...tokenContract,
          functionName: 'name',
        },
        {
          ...tokenContract,
          functionName: 'symbol',
        },
      ],
      allowFailure: true,
    });
    uri = result[0].result ? result[0].result.toString() : '';
    name = result[1].result ? result[1].result.toString() : '';
    symbol = result[2].result ? result[2].result.toString() : '';
  }

  let token: NFT;
  try {
    token = {
      type,
      symbol,
      name,
      uri: uri ? uri.toString() : undefined,
      addresses: {
        [srcChainId]: contractAddress,
      },
      tokenId,
      balance: balance ? balance : 0,
    } as NFT;
    try {
      if (!token.metadata) {
        const metadata: NFTMetadata | null = await fetchNFTMetadata(token);
        if (metadata) {
          token.metadata = metadata;
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
    abi: erc721ABI,
    functionName: 'name',
    chainId: srcChainId,
  });

  const symbol = await safeReadContract({
    address: contractAddress,
    abi: erc721ABI,
    functionName: 'symbol',
    chainId: srcChainId,
  });

  let uri;

  if (tokenId !== null && tokenId !== undefined) {
    uri = await safeReadContract({
      address: contractAddress,
      abi: erc721ABI,
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
