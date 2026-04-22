import { getTransaction } from '@wagmi/core';
import { get, writable } from 'svelte/store';
import { decodeFunctionData, type Hash } from 'viem';

import { erc721VaultAbi, erc1155VaultAbi } from '$abi';
import { InvalidParametersProvidedError } from '$libs/error';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { fetchNFTImageUrl } from './fetchNFTImageUrl';
import { getTokenWithInfoFromAddress } from './getTokenWithInfoFromAddress';
import { type NFT, TokenType } from './types';

const log = getLogger('libs:token:mapTransactionHashToNFT');

// Caching via store (could be moved to separate file but it is not used anywhere else)
const hashToNFTStore = writable<{ [hash: string]: NFT }>({});

export const mapTransactionHashToNFT = async ({
  hash,
  srcChainId,
  type,
}: {
  hash: Hash;
  srcChainId: number;
  type: TokenType;
}) => {
  if (type === TokenType.ETH || type === TokenType.ERC20)
    throw new InvalidParametersProvidedError('Invalid token type provided');

  // check store
  const store = get(hashToNFTStore);
  if (store[hash]) {
    log(`found token ${hash} in store`);
    return store[hash] as NFT;
  }
  log(`fetching transaction data for ${hash}`);
  // Retrieve transaction data
  const transactionData = await getTransaction(config, { hash, chainId: srcChainId });

  const abi = (() => {
    switch (type) {
      case TokenType.ERC721:
        return erc721VaultAbi;
      case TokenType.ERC1155:
        return erc1155VaultAbi;
      default:
        throw new Error('Invalid token type');
    }
  })();

  const { functionName, args: decodedInputData } = await decodeFunctionData({
    abi,
    data: transactionData.input,
  });
  if (!decodedInputData) throw new Error('Invalid input data');

  if (functionName !== 'sendToken') throw new Error('Invalid function name');

  const { token: tokenAddress, tokenIds } = decodedInputData[0];

  let token = (await getTokenWithInfoFromAddress({
    contractAddress: tokenAddress,
    srcChainId,
    tokenId: Number(tokenIds[0]),
    type,
  })) as NFT;
  token = await fetchNFTImageUrl(token);
  if (!token) throw new Error('Invalid token image');
  // cache the data
  hashToNFTStore.update((store) => ({ ...store, [hash]: token }));
  return token;
};
