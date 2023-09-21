import { fetchBalance, getPublicClient } from '@wagmi/core';
import { type Address, zeroAddress } from 'viem';

import { routingContractsMap } from '$bridgeConfig';
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
  fee?: bigint;
};

export async function checkBalanceToBridge({
  to,
  token,
  amount,
  balance,
  srcChainId,
  destChainId,
  fee,
}: HasEnoughBalanceToBridgeArgs) {
  const wallet = await getConnectedWallet();
  let estimatedCost = BigInt(0);

  const bridgeArgs = {
    to,
    amount,
    wallet,
    srcChainId,
    destChainId,
    fee,
  } as BridgeArgs;

  if (token.type === TokenType.ETH) {
    const { bridgeAddress } = routingContractsMap[srcChainId][destChainId];
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
    const { erc20VaultAddress } = routingContractsMap[srcChainId][destChainId];
    const tokenAddress = await getAddress({ token, srcChainId, destChainId });

    // since we are briding a token, we need the ETH balance of the wallet
    balance = await getPublicClient().getBalance(wallet.account);

    const tokenBalance = await fetchBalance({
      address: wallet.account.address,
      token: tokenAddress,
      chainId: srcChainId,
    });

    if (!tokenAddress || tokenAddress === zeroAddress || balance === BigInt(0) || tokenBalance.value < amount)
      throw new InsufficientBalanceError('you do not have enough balance to bridge');

    const bridge = bridges[token.type];

    if (bridge instanceof ERC20Bridge) {
      // Let's check the allowance to actually bridge the ERC20 token

      const allowance = await bridge.requireAllowance({
        amount,
        tokenAddress,
        ownerAddress: wallet.account.address,
        spenderAddress: erc20VaultAddress,
      });

      if (allowance) {
        throw new InsufficientAllowanceError(`insufficient allowance for the amount ${amount}`);
      }
    }

    const isTokenAlreadyDeployed = await isDeployedCrossChain({
      token,
      srcChainId,
      destChainId,
    });

    try {
      estimatedCost = await estimateCostOfBridging(bridges.ERC20, {
        ...bridgeArgs,
        token: tokenAddress,
        tokenVaultAddress: erc20VaultAddress,
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
