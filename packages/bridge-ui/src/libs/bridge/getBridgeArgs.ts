import { routingContractsMap } from '$bridgeConfig';
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
  nfts?: NFT[],
): Promise<BridgeArgsMap[typeof token.type]> => {
  if (!token) throw new Error('No token selected');
  switch (token.type) {
    case TokenType.ETH: {
      const bridgeAddress = routingContractsMap[commonArgs.srcChainId][commonArgs.destChainId].bridgeAddress;
      return { ...commonArgs, bridgeAddress, amount } as ETHBridgeArgs;
    }
    case TokenType.ERC20: {
      const fungibleToken = token as Token;
      const tokenAddress = await getAddress({
        token: fungibleToken,
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
      // The caller's captured selection, never the store: a selection changed since the
      // caller read it must not reach the transaction through a second read here
      if (!nfts?.length) throw new Error('No NFT selected');
      const tokenAddress = nfts[0].addresses[commonArgs.srcChainId];
      const tokenVaultAddress =
        routingContractsMap[commonArgs.srcChainId][commonArgs.destChainId][
          token.type === TokenType.ERC721 ? 'erc721VaultAddress' : 'erc1155VaultAddress'
        ];
      const tokenIds = nfts.map((nft) => BigInt(nft.tokenId));

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
        amounts: [token.type === TokenType.ERC721 ? 0n : amount],
      };
      return args as BridgeArgsMap[typeof token.type];
    }
    default:
      throw new Error('invalid token type');
  }
};
