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
import type { BridgeArgs, ERC20BridgeArgs, ERC1155BridgeArgs, ETHBridgeArgs } from './types';

type HasEnoughBalanceToBridgeArgs = {
  to: Address;
  token: Token;
  amount: bigint | bigint[];
  balance: bigint;
  srcChainId: number;
  destChainId: number;
  fee?: bigint;
  tokenIds?: bigint[];
};

export async function checkBalanceToBridge({
  to,
  token,
  amount,
  balance,
  srcChainId,
  destChainId,
  fee,
  tokenIds,
}: HasEnoughBalanceToBridgeArgs) {
  const wallet = await getConnectedWallet();
  let estimatedCost = BigInt(0);

  if (token.type === TokenType.ETH) {
    const { bridgeAddress } = routingContractsMap[srcChainId][destChainId];
    const bridgeArgs = {
      to,
      amount,
      wallet,
      srcChainId,
      destChainId,
      fee,
    } as BridgeArgs;

    const _amount = amount as bigint;

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
    if (estimatedCost > balance - _amount) {
      throw new InsufficientBalanceError('you do not have enough balance to bridge');
    }
  } else if (token.type === TokenType.ERC1155) {
    const bridgeArgs = {
      to,
      amounts: [amount],
      wallet,
      srcChainId,
      destChainId,
      fee,
      tokenIds,
    } as ERC1155BridgeArgs;

    const { erc1155VaultAddress } = routingContractsMap[srcChainId][destChainId];
    const tokenAddress = await getAddress({ token, srcChainId, destChainId });

    // since we are briding a token, we need the ETH balance of the wallet
    balance = await getPublicClient().getBalance(wallet.account);
    const tokenBalance = token.balance;
    const _amount = [amount] as bigint[];

    if (
      !tokenAddress ||
      !tokenBalance ||
      tokenAddress === zeroAddress ||
      balance === BigInt(0) ||
      tokenBalance < _amount[0] //TODO: only single token for now
    )
      throw new InsufficientBalanceError('you do not have enough balance to bridge');

    // const bridge = bridges[token.type];

    // if (bridge instanceof ERC1155Bridge) {
    //   // Let's check if the vault is approved for all ERC1155
    //   const isApprovedForAll = await bridge.isApprovedForAll({
    //     tokenAddress,
    //     owner: wallet.account.address,
    //     spenderAddress: erc1155VaultAddress,
    //     tokenId: 0n,
    //     chainId: srcChainId,
    //   });

    //   if (!isApprovedForAll) {
    //     throw new NotApprovedError(`Not approved for all for token`);
    //   }
    // }

    const isTokenAlreadyDeployed = await isDeployedCrossChain({
      token,
      srcChainId,
      destChainId,
    });

    try {
      estimatedCost = await estimateCostOfBridging(bridges.ERC1155, {
        ...bridgeArgs,
        token: tokenAddress,
        tokenVaultAddress: erc1155VaultAddress,
        isTokenAlreadyDeployed,
      } as BridgeArgs);
    } catch (err) {
      console.error(err);
      // if (err instanceof ContractFunctionExecutionError) {
      //   throw err;
      // }
      // TODO: catch/rethrow other errors
    }
    // no need to deduct the amount we want to bridge from the balance as we pay in ETH
    if (estimatedCost > balance) {
      throw new InsufficientBalanceError('you do not have enough balance to bridge');
    }
  } else {
    const { erc20VaultAddress } = routingContractsMap[srcChainId][destChainId];
    const tokenAddress = await getAddress({ token, srcChainId, destChainId });
    const _amount = amount as bigint;

    // since we are briding a token, we need the ETH balance of the wallet
    balance = await getPublicClient().getBalance(wallet.account);

    const tokenBalance = await fetchBalance({
      address: wallet.account.address,
      token: tokenAddress,
      chainId: srcChainId,
    });

    if (!tokenAddress || tokenAddress === zeroAddress || balance === BigInt(0) || tokenBalance.value < _amount)
      throw new InsufficientBalanceError('you do not have enough balance to bridge');

    const bridge = bridges[token.type];

    if (bridge instanceof ERC20Bridge) {
      // Let's check the allowance to actually bridge the ERC20 token
      const allowance = await bridge.requireAllowance({
        amount: _amount,
        tokenAddress,
        ownerAddress: wallet.account.address,
        spenderAddress: erc20VaultAddress,
      });

      if (allowance) {
        throw new InsufficientAllowanceError(`insufficient allowance for the amount ${_amount}`);
      }
    }

    const isTokenAlreadyDeployed = await isDeployedCrossChain({
      token,
      srcChainId,
      destChainId,
    });

    try {
      const bridgeArgs = {
        to,
        amount,
        wallet,
        srcChainId,
        destChainId,
        fee,
      } as BridgeArgs;

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
