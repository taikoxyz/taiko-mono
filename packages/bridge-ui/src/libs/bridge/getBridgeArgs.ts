import { get } from 'svelte/store';

import { routingContractsMap } from '$bridgeConfig';
import { selectedNFTs } from '$components/Bridge/state';
import { NoCanonicalInfoFoundError } from '$libs/error';
import { getAddress, type NFT, type Token, TokenType } from '$libs/token';
import { getTokenAddresses } from '$libs/token/getTokenAddresses';

import type { BridgeArgs, BridgeArgsMap, ERC20BridgeArgs, ETHBridgeArgs } from './types';

export const getBridgeArgs = async (
  token: Token | NFT,
  amount: bigint | bigint[],
  commonArgs: Omit<
    BridgeArgs,
    'bridgeAddress' | 'token' | 'tokenVaultAddress' | 'isTokenAlreadyDeployed' | 'tokenIds' | 'amount'
  >,
  nftIdArray?: number[],
): Promise<BridgeArgsMap[typeof token.type]> => {
  if (!token) throw new Error('No token selected');
  switch (token.type) {
    case TokenType.ETH: {
      const bridgeAddress = routingContractsMap[commonArgs.srcChainId][commonArgs.destChainId].bridgeAddress;
      return { ...commonArgs, bridgeAddress, amount } as ETHBridgeArgs;
    }
    case TokenType.ERC20: {
      const tokenAddress = await getAddress({
        token,
        srcChainId: commonArgs.srcChainId,
        destChainId: commonArgs.destChainId,
      });
      const tokenVaultAddress = routingContractsMap[commonArgs.srcChainId][commonArgs.destChainId].erc20VaultAddress;

      const tokenInfo = await getTokenAddresses({
        token,
        srcChainId: commonArgs.srcChainId,
        destChainId: commonArgs.destChainId,
      });
      if (!tokenInfo) throw new NoCanonicalInfoFoundError();

      let isTokenAlreadyDeployed = false;

      if (tokenInfo.bridged) {
        const { address } = tokenInfo.bridged;
        if (address) {
          isTokenAlreadyDeployed = true;
        }
      }

      return {
        ...commonArgs,
        token: tokenAddress,
        tokenVaultAddress,
        isTokenAlreadyDeployed,
        amount,
      } as ERC20BridgeArgs;
    }
    case TokenType.ERC721:
    case TokenType.ERC1155: {
      const nfts = get(selectedNFTs);

      if (!nfts) throw new Error('No NFT selected');
      const tokenAddress = nfts[0].addresses[commonArgs.srcChainId];
      const tokenVaultAddress =
        routingContractsMap[commonArgs.srcChainId][commonArgs.destChainId][
          token.type === TokenType.ERC721 ? 'erc721VaultAddress' : 'erc1155VaultAddress'
        ];
      const tokenIds = nftIdArray ? nftIdArray.map((num) => BigInt(num)) : nfts.map((nft) => BigInt(nft.tokenId));

      const tokenInfo = await getTokenAddresses({
        token,
        srcChainId: commonArgs.srcChainId,
        destChainId: commonArgs.destChainId,
      });
      if (!tokenInfo) throw new NoCanonicalInfoFoundError();

      let isTokenAlreadyDeployed = false;

      if (tokenInfo.bridged) {
        const { address } = tokenInfo.bridged;
        if (address) {
          isTokenAlreadyDeployed = true;
        }
      }

      const args = {
        ...commonArgs,
        token: tokenAddress,
        tokenVaultAddress,
        isTokenAlreadyDeployed,
        tokenIds: tokenIds.map((id) => Number(id)),
        amounts: [token.type === TokenType.ERC721 ? 0 : Number(amount)],
      };
      return args as BridgeArgsMap[typeof token.type];
    }
    default:
      throw new Error('invalid token type');
  }
};
