import { getPublicClient } from '@wagmi/core';

import { gasLimitConfig } from '$config';
import { PUBLIC_FEE_MULTIPLIER } from '$env/static/public';
import { NoCanonicalInfoFoundError } from '$libs/error';
import { type Token, TokenType } from '$libs/token';
import { getTokenAddresses } from '$libs/token/getTokenAddresses';
import { getBaseFee } from '$libs/util/getBaseFee';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

const log = getLogger('libs:recommendedProcessingFee');

type RecommendProcessingFeeArgs = {
  token: Token;
  destChainId: number;
  srcChainId?: number;
};

export async function recommendProcessingFee({
  token,
  destChainId,
  srcChainId,
}: RecommendProcessingFeeArgs): Promise<bigint> {
  if (!srcChainId) {
    return 0n;
  }

  let estimatedMsgGaslimit;

  const baseFee = await getBaseFee(BigInt(destChainId));
  log(`Base fee: ${baseFee}`);

  const destPublicClient = getPublicClient(config, { chainId: destChainId });

  if (!destPublicClient) throw new Error('Could not get public client');

  const maxPriorityFee = await destPublicClient.estimateMaxPriorityFeePerGas();
  log(`Max priority fee: ${maxPriorityFee}`);

  if (!baseFee) throw new Error('Unable to get base fee');

  if (token.type !== TokenType.ETH) {
    const tokenInfo = await getTokenAddresses({ token, srcChainId, destChainId });
    if (!tokenInfo) throw new NoCanonicalInfoFoundError();

    let isTokenAlreadyDeployed = false;

    if (tokenInfo.bridged) {
      const { address } = tokenInfo.bridged;
      if (address) {
        isTokenAlreadyDeployed = true;
      }
    }
    if (token.type === TokenType.ERC20) {
      if (isTokenAlreadyDeployed) {
        log(`token ${token.symbol} is already deployed on chain ${destChainId}`);

        estimatedMsgGaslimit = BigInt(gasLimitConfig.GAS_RESERVE) + gasLimitConfig.erc20DeployedGasLimit;
        log(
          `calculation ${gasLimitConfig.GAS_RESERVE} + ${gasLimitConfig.erc20DeployedGasLimit} = ${estimatedMsgGaslimit}`,
        );
      } else {
        log(`token ${token.symbol} is not deployed on chain ${destChainId}`);
        estimatedMsgGaslimit = BigInt(gasLimitConfig.GAS_RESERVE) + gasLimitConfig.erc20NotDeployedGasLimit;
        log(
          `calculation ${gasLimitConfig.GAS_RESERVE} + ${gasLimitConfig.erc20NotDeployedGasLimit} = ${estimatedMsgGaslimit}`,
        );
      }
    } else if (token.type === TokenType.ERC721) {
      if (isTokenAlreadyDeployed) {
        log(`token ${token.symbol} is already deployed on chain ${destChainId}`);
        estimatedMsgGaslimit = BigInt(gasLimitConfig.GAS_RESERVE) + gasLimitConfig.erc721DeployedGasLimit;
      } else {
        log(`token ${token.symbol} is not deployed on chain ${destChainId}`);
        estimatedMsgGaslimit = BigInt(gasLimitConfig.GAS_RESERVE) + gasLimitConfig.erc721NotDeployedGasLimit;
      }
    } else if (token.type === TokenType.ERC1155) {
      if (isTokenAlreadyDeployed) {
        log(`token ${token.symbol} is already deployed on chain ${destChainId}`);
        estimatedMsgGaslimit = BigInt(gasLimitConfig.GAS_RESERVE) + gasLimitConfig.erc1155DeployedGasLimit;
      } else {
        log(`token ${token.symbol} is not deployed on chain ${destChainId}`);
        estimatedMsgGaslimit = BigInt(gasLimitConfig.GAS_RESERVE) + gasLimitConfig.erc1155NotDeployedGasLimit;
      }
    }
  } else {
    log(`Fee for ETH bridging`);
    estimatedMsgGaslimit = BigInt(gasLimitConfig.GAS_RESERVE);
    log(`calculation ${gasLimitConfig.GAS_RESERVE}  = ${estimatedMsgGaslimit}`);
  }
  if (!estimatedMsgGaslimit) throw new Error('Unable to calculate fee');

  const fee = estimatedMsgGaslimit * (BigInt(PUBLIC_FEE_MULTIPLIER) * (baseFee + maxPriorityFee));
  log(`Formula: ${estimatedMsgGaslimit} * ${PUBLIC_FEE_MULTIPLIER} * (${baseFee} + ${maxPriorityFee})) = ${fee}`);

  log(`Recommended fee: ${fee.toString()}`);
  return roundWeiTo6DecimalPlaces(fee);
}

function roundWeiTo6DecimalPlaces(wei: bigint): bigint {
  const roundingFactor = BigInt('1000000000000'); // 10^12

  // Calculate how many "10^12 wei" units are in the input
  const units = wei / roundingFactor;

  // Multiply back to get the rounded wei value
  const roundedWei = units * roundingFactor;
  return roundedWei;
}
