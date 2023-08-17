import { getPublicClient } from '@wagmi/core';
import { type Address, zeroAddress } from 'viem';

import { chainContractsMap } from '$libs/chain';
import { InsufficientAllowanceError, InsufficientBalanceError, RevertedWithFailedError } from '$libs/error';
import { getAddress, type Token, TokenType } from '$libs/token';
import { isDeployedCrossChain } from '$libs/token/isDeployedCrossChain';
import { getConnectedWallet } from '$libs/util/getConnectedWallet';

import { bridges } from './bridges';
import { ERC20Bridge } from './ERC20Bridge';
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
    if (estimatedCost > balance - amount) {
      throw new InsufficientBalanceError('you do not have enough balance to bridge');
    }
  } else {
    const { tokenVaultAddress } = chainContractsMap[srcChainId];
    const tokenAddress = await getAddress({ token, srcChainId, destChainId });

    // since we are briding a token, we need the ETH balance of the wallet
    balance = await getPublicClient().getBalance(wallet.account);

    if (!tokenAddress || tokenAddress === zeroAddress) return false;

    const bridge = bridges[token.type];

    if (bridge instanceof ERC20Bridge) {
      // Let's check the allowance to actually bridge the ERC20 token

      const allowance = await bridge.requireAllowance({
        amount,
        tokenAddress,
        ownerAddress: wallet.account.address,
        spenderAddress: tokenVaultAddress,
      });

      if (allowance) {
        throw new InsufficientAllowanceError(`insufficient allowance for the amount ${amount}`);
      }
    }

    // since we are briding a token, we need the ETH balance of the wallet
    balance = await getPublicClient().getBalance(wallet.account);

    const isTokenAlreadyDeployed = await isDeployedCrossChain({
      token,
      srcChainId,
      destChainId,
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
    // no need to deduct the amount we want to bridge from the balance as we pay in ETH
    if (estimatedCost > balance) {
      throw new InsufficientBalanceError('you do not have enough balance to bridge');
    }
  }
}
