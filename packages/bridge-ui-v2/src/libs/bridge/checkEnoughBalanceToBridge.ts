import { type Address, zeroAddress } from 'viem';

import { chainContractsMap } from '$libs/chain';
import { getAddress, isETH, type Token } from '$libs/token';
import { isDeployedCrossChain } from '$libs/token/isDeployedCrossChain';

import { bridges } from './bridges';
import { estimateCostOfBridging } from './estimateCostOfBridging';
import type { BridgeArgs, ERC20BridgeArgs, ETHBridgeArgs } from './types';

type HasEnoughBalanceToBridgeArgs = {
  to: Address;
  token: Token;
  amount: bigint;
  balance: bigint;
  srcChainId: number;
  destChainId: number;
  processingFee?: bigint;
};

export async function hasEnoughBalanceToBridge({
  to,
  token,
  amount,
  balance,
  srcChainId,
  destChainId,
  processingFee,
}: HasEnoughBalanceToBridgeArgs) {
  let estimatedCost = BigInt(0);

  const bridgeArgs = {
    to,
    amount,
    srcChainId,
    destChainId,
    processingFee,
  } as BridgeArgs;

  if (isETH(token)) {
    const { bridgeAddress } = chainContractsMap[srcChainId];

    estimatedCost = await estimateCostOfBridging(bridges.ETH, {
      ...bridgeArgs,
      bridgeAddress,
    } as ETHBridgeArgs);
  } else {
    const { tokenVaultAddress } = chainContractsMap[srcChainId];
    const tokenAddress = await getAddress({ token, srcChainId, destChainId });

    if (!tokenAddress || tokenAddress === zeroAddress) return false;

    const isTokenAlreadyDeployed = await isDeployedCrossChain({ token, destChainId, srcChainId });

    estimatedCost = await estimateCostOfBridging(bridges.ERC20, {
      ...bridgeArgs,
      tokenAddress,
      tokenVaultAddress,
      isTokenAlreadyDeployed,
    } as ERC20BridgeArgs);
  }

  return balance - amount > estimatedCost;
}
