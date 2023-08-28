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

const { ethGasLimit, erc20NotDeployedGasLimit, erc20DeployedGasLimit } = recommentProcessingFee;

export async function recommendProcessingFee({ token, destChainId, srcChainId }: RecommendProcessingFeeArgs) {
  const destPublicClient = getPublicClient({ chainId: destChainId });
  // getGasPrice will return gasPrice as 3000000001, rather than 3000000000
  const gasPrice = await destPublicClient.getGasPrice();

  // The gas limit for processMessage call for ETH is about ~800k.
  // To make it enticing, we say 900k
  let gasLimit = ethGasLimit;

  if (token.type === TokenType.ERC20) {
    if (!srcChainId) {
      throw Error('missing required source chain for ERC20 token');
    }

    const isTokenAlreadyDeployed = await isDeployedCrossChain({
      token,
      srcChainId,
      destChainId,
    });

    if (isTokenAlreadyDeployed) {
      // Gas limit for erc20 if already deployed on the destination chain is
      // about ~1m, so again, add some to ensure processing
      gasLimit = erc20DeployedGasLimit;
      log(`token ${token.symbol} is already deployed on chain ${destChainId}`);
    } else {
      // Gas limit for erc20 if not deployed on the destination chain
      // already is about ~2.9m, so we add some to make it enticing
      gasLimit = erc20NotDeployedGasLimit;
      log(`token ${token.symbol} is not deployed on chain ${destChainId}`);
    }
  }

  return gasPrice * gasLimit;
}
