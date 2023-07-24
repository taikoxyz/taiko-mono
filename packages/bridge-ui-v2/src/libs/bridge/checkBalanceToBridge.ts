import { type Address, zeroAddress } from 'viem';

import { chainContractsMap } from '$libs/chain';
import { InsufficientAllowanceError, InsufficientBalanceError, RevertedWithFailedError } from '$libs/error';
import { getAddress, type Token, TokenType } from '$libs/token';
import { isDeployedCrossChain } from '$libs/token/isDeployedCrossChain';
import { getConnectedWallet } from '$libs/util/getConnectedWallet';

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
  const wallet = await getConnectedWallet();
  let estimatedCost = BigInt(0);

  const bridgeArgs = {
    to,
    amount,
    wallet,
    srcChainId,
    destChainId,
    processingFee,
  } as BridgeArgs;

  if (token.type === TokenType.ETH) {
    const { bridgeAddress } = chainContractsMap[srcChainId];

    try {
      estimatedCost = await estimateCostOfBridging(bridges.ETH, {
        ...bridgeArgs,
        bridgeAddress,
      } as ETHBridgeArgs);
    } catch (err) {
      console.error(err);

      // TODO: rely on error code, or instance, instead of string matching
      if (`${err}`.includes('transaction exceeds the balance')) {
        throw new InsufficientBalanceError('you do not have enough balance to bridge ETH', { cause: err });
      }

      if (`${err}`.includes('reverted with the following reason: Failed')) {
        throw new RevertedWithFailedError('BLL token doing its thing', { cause: err });
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

      // TODO: same here. Error code or instance would be better
      if (`${err}`.includes('insufficient allowance')) {
        throw new InsufficientAllowanceError(`insufficient allowance for the amount ${amount}`, { cause: err });
      }
    }
  }

  if (estimatedCost > balance - amount) {
    throw new InsufficientBalanceError('you do not have enough balance to bridge');
  }
}
