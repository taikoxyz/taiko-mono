import { getPublicClient } from '@wagmi/core';

import { recommentProcessingFee } from '$config';
import { isDeployedCrossChain, type Token, TokenType } from '$libs/token';
import { getLogger } from '$libs/util/logger';

const log = getLogger('libs:recommendedProcessingFee');

type RecommendProcessingFeeArgs = {
  token: Token;
  destChainId: number;
  srcChainId?: number;
};

const {
  ethGasLimit,
  erc20NotDeployedGasLimit,
  erc20DeployedGasLimit,
  erc1155DeployedGasLimit,
  erc1155NotDeployedGasLimit,
  erc721DeployedGasLimit,
  erc721NotDeployedGasLimit,
} = recommentProcessingFee;

export async function recommendProcessingFee({ token, destChainId, srcChainId }: RecommendProcessingFeeArgs) {
  if (!srcChainId) {
    throw Error('missing required source chain');
  }
  const destPublicClient = getPublicClient({ chainId: destChainId });
  // getGasPrice will return gasPrice as 3000000001, rather than 3000000000
  const gasPrice = await destPublicClient.getGasPrice();

  // The gas limit for processMessage call for ETH is about ~800k.
  // To make it enticing, we say 900k
  let gasLimit = ethGasLimit;

  if (token.type === TokenType.ERC20) {
    const isTokenAlreadyDeployed = await isDeployedCrossChain({
      token,
      srcChainId,
      destChainId,
    });

    if (isTokenAlreadyDeployed) {
      gasLimit = erc20DeployedGasLimit;
      log(`token ${token.symbol} is already deployed on chain ${destChainId}`);
    } else {
      gasLimit = erc20NotDeployedGasLimit;
      log(`token ${token.symbol} is not deployed on chain ${destChainId}`);
    }
  } else if (token.type === TokenType.ERC721) {
    const isTokenAlreadyDeployed = await isDeployedCrossChain({
      token,
      srcChainId,
      destChainId,
    });
    if (isTokenAlreadyDeployed) {
      gasLimit = erc721DeployedGasLimit;
      log(`token ${token.symbol} is already deployed on chain ${destChainId}`);
    } else {
      gasLimit = erc721NotDeployedGasLimit;
      log(`token ${token.symbol} is not deployed on chain ${destChainId}`);
    }
  } else if (token.type === TokenType.ERC1155) {
    const isTokenAlreadyDeployed = await isDeployedCrossChain({
      token,
      srcChainId,
      destChainId,
    });
    if (isTokenAlreadyDeployed) {
      gasLimit = erc1155DeployedGasLimit;
      log(`token ${token.symbol} is already deployed on chain ${destChainId}`);
    } else {
      gasLimit = erc1155NotDeployedGasLimit;
      log(`token ${token.symbol} is not deployed on chain ${destChainId}`);
    }
  }

  return gasPrice * gasLimit;
}
