import { erc721ABI, fetchToken, readContract } from '@wagmi/core';
import type { Address } from 'viem';

import { erc1155ABI } from '$abi';
import { getLogger } from '$libs/util/logger';
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
      const fetchResult = await fetchToken({
        address: contractAddress,
        chainId: srcChainId,
      });

      const token = {
        type: tokenType,
        name: fetchResult.name,
        symbol: fetchResult.symbol,
        addresses: {
          [srcChainId]: contractAddress,
        },
        decimals: fetchResult.decimals,
      } as Token;

      return token;
    } else if (tokenType === TokenType.ERC1155) {
      const name = await safeReadContract({
        address: contractAddress,
        abi: erc1155ABI,
        functionName: 'name',
        chainId: srcChainId,
      });

      const uri = await safeReadContract({
        address: contractAddress,
        abi: erc1155ABI,
        functionName: 'uri',
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

      const token = {
        type: tokenType,
        name: name ? name : 'No name specified',
        uri: uri ? uri.toString() : undefined,
        addresses: {
          [srcChainId]: contractAddress,
        },
        tokenId,
        balance: balance ? balance : 0,
      } as NFT;
      // todo: fetch more details via URI?

      return token;
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
