import { getPublicClient } from '@wagmi/core';
import { getContract } from 'viem';

import { bridgeAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { gasLimitConfig } from '$config';
import { type NFT, type Token, TokenType } from '$libs/token/types';
import { config } from '$libs/wagmi';

import { calculateMessageDataSize } from './calculateMessageDataSize';

type EstimateMessageGasLimitArgs = {
  token: Token | NFT;
  srcChainId: number;
  destChainId: number;
  isTokenAlreadyDeployed?: boolean;
  tokenIds?: number[];
  amounts?: number[];
};

export async function estimateMessageGasLimit({
  token,
  srcChainId,
  destChainId,
  isTokenAlreadyDeployed = false,
  tokenIds,
  amounts,
}: EstimateMessageGasLimitArgs): Promise<number> {
  const { size } = await calculateMessageDataSize({ token, chainId: srcChainId, tokenIds, amounts });
  const minGasLimit = await getDestinationMessageMinGasLimit({ srcChainId, destChainId, dataSize: size });

  switch (token.type) {
    case TokenType.ETH:
      return minGasLimit + 1;
    case TokenType.ERC20:
      return (
        minGasLimit +
        (isTokenAlreadyDeployed ? gasLimitConfig.erc20DeployedGasLimit : gasLimitConfig.erc20NotDeployedGasLimit)
      );
    case TokenType.ERC721:
      return (
        minGasLimit +
        (isTokenAlreadyDeployed ? gasLimitConfig.erc721DeployedGasLimit : gasLimitConfig.erc721NotDeployedGasLimit)
      );
    case TokenType.ERC1155:
      return (
        minGasLimit +
        (isTokenAlreadyDeployed ? gasLimitConfig.erc1155DeployedGasLimit : gasLimitConfig.erc1155NotDeployedGasLimit)
      );
    default:
      throw new Error(`Unsupported token type: ${token.type}`);
  }
}

async function getDestinationMessageMinGasLimit({
  srcChainId,
  destChainId,
  dataSize,
}: {
  srcChainId: number;
  destChainId: number;
  dataSize: number;
}): Promise<number> {
  const client = getPublicClient(config, { chainId: destChainId });
  if (!client) throw new Error('Could not get public client');

  const destBridgeAddress = routingContractsMap[destChainId][srcChainId].bridgeAddress;
  const destBridgeContract = getContract({
    client,
    abi: bridgeAbi,
    address: destBridgeAddress,
  });

  return Number(await destBridgeContract.read.getMessageMinGasLimit([BigInt(dataSize)]));
}
