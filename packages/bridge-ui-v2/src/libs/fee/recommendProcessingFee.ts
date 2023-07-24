import { getPublicClient } from '@wagmi/core';
import { zeroAddress } from 'viem';

import { recommentProcessingFee } from '$config';
import { getAddress, isERC20, type Token } from '$libs/token';

type RecommendProcessingFeeArgs = {
  token: Token;
  destChainId: number;
  srcChainId?: number;
};

const { ethGasLimit, erc20NotDeployedGasLimit, erc20DeployedGasLimit } = recommentProcessingFee;

export async function recommendProcessingFee({ token, destChainId, srcChainId }: RecommendProcessingFeeArgs) {
  const destPublicClient = getPublicClient({ chainId: destChainId });
  const gasPrice = await destPublicClient.getGasPrice();

  // The gas limit for processMessage call for ETH is about ~800k.
  // To make it enticing, we say 900k
  let gasLimit = ethGasLimit;

  if (isERC20(token)) {
    if (!srcChainId) {
      throw Error('missing required source chain for ERC20 token');
    }

    const tokenAddress = await getAddress({ token, srcChainId, destChainId });

    if (!tokenAddress || tokenAddress === zeroAddress) {
      // Gas limit for erc20 if not deployed on the destination chain
      // already is about ~2.9m, so we add some to make it enticing
      gasLimit = erc20NotDeployedGasLimit;
    } else {
      // Gas limit for erc20 if already deployed on the destination chain is
      // about ~1m, so again, add some to ensure processing
      gasLimit = erc20DeployedGasLimit;
    }
  }

  return gasPrice * gasLimit;
}
