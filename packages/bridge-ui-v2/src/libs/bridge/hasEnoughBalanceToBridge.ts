import { type Address, zeroAddress } from 'viem';

import { chainContractsMap } from '$libs/chain';
import { getAddress, isETH, type Token } from '$libs/token';
import { isDeployedCrossChain } from '$libs/token/isDeployedCrossChain';

import { bridges } from './bridges';
import { estimateCostOfBridging } from './estimateCostOfBridging';
import type { ERC20BridgeArgs, ETHBridgeArgs } from './types';

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
  if (isETH(token)) {
    const { bridgeAddress } = chainContractsMap[srcChainId];

    const bridgeArgs = {
      to,
      amount,
      srcChainId,
      destChainId,
      bridgeAddress,
      processingFee,
    } as ETHBridgeArgs;

    const estimatedCost = await estimateCostOfBridging(bridges.ETH, bridgeArgs);

    return balance - amount > estimatedCost;
  } else {
    const { tokenVaultAddress } = chainContractsMap[srcChainId];
    const tokenAddress = await getAddress({ token, srcChainId, destChainId });

    if (!tokenAddress || tokenAddress === zeroAddress) return false;

    const isTokenAlreadyDeployed = await isDeployedCrossChain({ token, destChainId, srcChainId });

    const bridgeArgs = {
      to,
      amount,
      srcChainId,
      destChainId,
      processingFee,
      tokenAddress,
      tokenVaultAddress,
      isTokenAlreadyDeployed,
    } as ERC20BridgeArgs;

    const estimatedCost = await estimateCostOfBridging(bridges.ERC20, bridgeArgs);

    return balance - amount > estimatedCost;
  }
}
