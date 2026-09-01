import { getPublicClient } from '@wagmi/core';
import { getContract } from 'viem';

import { bridgeAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { gasLimitConfig } from '$config';
import { type NFT, type Token, TokenType } from '$libs/token/types';
import { config } from '$libs/wagmi';

import { calculateMessageDataSize } from './calculateMessageDataSize';

/**
 * What the destination gas estimate needs beyond the token and the two chains. Named so
 * the shared send preamble can pass a token type's own sizing inputs straight through.
 */
export type MessageGasEstimateExtras = {
  isTokenAlreadyDeployed?: boolean;
  tokenIds?: number[];
  amounts?: bigint[];
};

type EstimateMessageGasLimitArgs = MessageGasEstimateExtras & {
  token: Token | NFT;
  srcChainId: number;
  destChainId: number;
};

/**
 * @dev Estimates the destination gas limit and reports the contract minimum it was built
 *      from.
 *
 *      The minimum is returned rather than discarded because the message invariants have a
 *      rule about it - Bridge.sendMessage subtracts the minimum and rejects a remainder of
 *      zero - and that rule was unenforceable while no caller could supply the number.
 *
 * @param args The token, both chains and the vault's own sizing inputs
 * @return estimate_ The gas limit to send and the minimum the destination bridge requires
 */
export async function estimateMessageGasLimitWithMinimum({
  token,
  srcChainId,
  destChainId,
  isTokenAlreadyDeployed = false,
  tokenIds,
  amounts,
}: EstimateMessageGasLimitArgs): Promise<{ gasLimit: number; minGasLimit: number }> {
  const { size } = await calculateMessageDataSize({ token, chainId: srcChainId, tokenIds, amounts });
  const minGasLimit = await getDestinationMessageMinGasLimit({ srcChainId, destChainId, dataSize: size });

  const headroom = (): number => {
    switch (token.type) {
      case TokenType.ETH:
        return 1;
      case TokenType.ERC20:
        return isTokenAlreadyDeployed ? gasLimitConfig.erc20DeployedGasLimit : gasLimitConfig.erc20NotDeployedGasLimit;
      case TokenType.ERC721:
        return isTokenAlreadyDeployed
          ? gasLimitConfig.erc721DeployedGasLimit
          : gasLimitConfig.erc721NotDeployedGasLimit;
      case TokenType.ERC1155:
        return isTokenAlreadyDeployed
          ? gasLimitConfig.erc1155DeployedGasLimit
          : gasLimitConfig.erc1155NotDeployedGasLimit;
      default:
        throw new Error(`Unsupported token type: ${token.type}`);
    }
  };

  return { gasLimit: minGasLimit + headroom(), minGasLimit };
}

export async function estimateMessageGasLimit(args: EstimateMessageGasLimitArgs): Promise<number> {
  return (await estimateMessageGasLimitWithMinimum(args)).gasLimit;
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
