import { type Address, zeroAddress } from 'viem';

import { chainContractsMap } from '$libs/chain';
import { InsufficientAllowanceError, InsufficientBalanceError } from '$libs/error';
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

export async function checkBalanceToBridge({
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

    try {
      estimatedCost = await estimateCostOfBridging(bridges.ETH, {
        ...bridgeArgs,
        bridgeAddress,
      } as ETHBridgeArgs);
    } catch (err) {
      console.error(err);

      if (`${err}`.includes('transaction exceeds the balance of the account')) {
        throw new InsufficientBalanceError('you do not have enough balance to bridge ETH', { cause: err });
      }
    }
  } else {
    const { tokenVaultAddress } = chainContractsMap[srcChainId];
    const tokenAddress = await getAddress({ token, srcChainId, destChainId });

    if (!tokenAddress || tokenAddress === zeroAddress) return false;

    const isTokenAlreadyDeployed = await isDeployedCrossChain({
      token,
      srcChainId: destChainId,
      destChainId: srcChainId,
    });

    try {
      estimatedCost = await estimateCostOfBridging(bridges.ERC20, {
        ...bridgeArgs,
        tokenAddress,
        tokenVaultAddress,
        isTokenAlreadyDeployed,
      } as ERC20BridgeArgs);
    } catch (err) {
      console.error(err);

      if (`${err}`.includes('insufficient allowance')) {
        throw new InsufficientAllowanceError(`insufficient allowance for the amount ${amount}`, { cause: err });
      }
    }
  }

  if (estimatedCost > balance - amount) {
    throw new InsufficientBalanceError('you do not have enough balance to bridge');
  }
}
