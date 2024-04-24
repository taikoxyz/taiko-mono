import { getBalance } from '@wagmi/core';
import { type Address, zeroAddress } from 'viem';

import { routingContractsMap } from '$bridgeConfig';
import {
  InsufficientAllowanceError,
  InsufficientBalanceError,
  NoCanonicalInfoFoundError,
  RevertedWithFailedError,
  RevertedWithoutMessageError,
} from '$libs/error';
import { getAddress, type Token, TokenType } from '$libs/token';
import { getTokenAddresses } from '$libs/token/getTokenAddresses';
import { getConnectedWallet } from '$libs/util/getConnectedWallet';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { bridges } from './bridges';
import { ERC20Bridge } from './ERC20Bridge';
import { estimateCostOfBridging } from './estimateCostOfBridging';
import type { ERC20BridgeArgs, ERC1155BridgeArgs, ETHBridgeArgs } from './types';

const log = getLogger('token:checkBalanceToBridge');

type CheckBalanceToBridgeCommonArgs = {
  to: Address;
  amount: bigint | bigint[];
  srcChainId: number;
  destChainId: number;
  fee?: bigint;
};

type CheckBalanceToBridgeTokenArgs = CheckBalanceToBridgeCommonArgs & {
  token: Token;
  balance: bigint;
  tokenIds?: bigint[];
};

export async function checkBalanceToBridge(args: CheckBalanceToBridgeTokenArgs) {
  switch (args.token.type) {
    case TokenType.ETH:
      return handleEthBridge({ ...args });
    case TokenType.ERC1155:
      return handleErc1155Bridge({ ...args });
    case TokenType.ERC20:
      return handleErc20Bridge({ ...args });
    default:
      throw new Error('Unsupported token type');
  }
}

async function handleEthBridge(args: CheckBalanceToBridgeCommonArgs): Promise<void> {
  const { bridgeAddress } = routingContractsMap[args.srcChainId][args.destChainId];
  const _amount = args.amount as bigint;

  const wallet = await getConnectedWallet();
  let estimatedCost;
  try {
    estimatedCost = await estimateCostOfBridging(bridges.ETH, {
      ...args,
      wallet,
      bridgeAddress,
    } as ETHBridgeArgs);
  } catch (err) {
    console.error(err);

    if (`${err}`.includes('transaction exceeds the balance')) {
      throw new InsufficientBalanceError('you do not have enough balance to bridge ETH', { cause: err });
    }

    if (`${err}`.includes('reverted with the following reason: Failed')) {
      throw new RevertedWithFailedError('BLL token doing its thing', { cause: err });
    }
    throw new RevertedWithoutMessageError('reverted without reason', { cause: err });
  }

  if (!estimatedCost) throw new Error('estimated cost is undefined');
  const balance = await getBalance(config, { address: wallet.account.address, chainId: args.srcChainId });

  if (estimatedCost > balance.value - _amount) {
    throw new InsufficientBalanceError('you do not have enough balance to bridge');
  }
}

async function handleErc1155Bridge(args: CheckBalanceToBridgeTokenArgs) {
  const { token, srcChainId, destChainId, amount } = args;

  const { erc1155VaultAddress } = routingContractsMap[srcChainId][destChainId];
  const tokenAddress = await getAddress({ token, srcChainId, destChainId });
  const wallet = await getConnectedWallet();
  const balance = (await getBalance(config, { address: wallet.account.address, chainId: args.srcChainId })).value;
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

  const tokenInfo = await getTokenAddresses({ token, srcChainId, destChainId });
  if (!tokenInfo) throw new NoCanonicalInfoFoundError();

  let isTokenAlreadyDeployed = false;

  if (tokenInfo.bridged) {
    const { address } = tokenInfo.bridged;
    if (address && address !== tokenAddress) {
      // we have a bridged token, no need for allowance check as we will burn the token
      log('token is bridged, no need for allowance check');
      return;
    } else if (address && address === tokenAddress) {
      log('Token already deployed to destination chain', address, tokenInfo.bridged.chainId);
      isTokenAlreadyDeployed = true;
    }
  }
  let estimatedCost;
  try {
    estimatedCost = await estimateCostOfBridging(bridges.ERC1155, {
      ...args,
      wallet,
      amounts: _amount.map((a) => Number(a)),
      token: tokenAddress,
      tokenVaultAddress: erc1155VaultAddress,
      isTokenAlreadyDeployed,
      tokenObject: token,
      tokenIds: args.tokenIds?.map((a) => Number(a)),
    } as ERC1155BridgeArgs);
  } catch (err) {
    console.error(err);
    // TODO: catch/rethrow other errors
  }

  if (!estimatedCost) throw new Error('estimated cost is undefined');
  if (estimatedCost && estimatedCost > balance) {
    throw new InsufficientBalanceError('you do not have enough balance to bridge');
  }
}

async function handleErc20Bridge(args: CheckBalanceToBridgeTokenArgs): Promise<void> {
  const { token, srcChainId, destChainId, amount, balance } = args;
  const wallet = await getConnectedWallet();
  const { erc20VaultAddress } = routingContractsMap[srcChainId][destChainId];
  const tokenAddress = await getAddress({ token, srcChainId, destChainId });
  const _amount = amount as bigint;

  const tokenBalance = await getBalance(config, {
    address: wallet.account.address,
    token: tokenAddress,
    chainId: args.srcChainId,
  });

  if (!tokenAddress || tokenAddress === zeroAddress || args.balance === BigInt(0) || tokenBalance.value < _amount)
    throw new InsufficientBalanceError('you do not have enough balance to bridge');

  const bridge = bridges[args.token.type];

  if (bridge instanceof ERC20Bridge) {
    const tokenInfo = await getTokenAddresses({ token, srcChainId, destChainId });
    if (!tokenInfo) throw new NoCanonicalInfoFoundError();

    let isTokenAlreadyDeployed = false;

    if (tokenInfo.bridged) {
      const { address } = tokenInfo.bridged;
      if (address && address !== tokenAddress) {
        // we have a bridged token, no need for allowance check as we will burn the token
        log('token is bridged, no need for allowance check');
        return;
      } else if (address && address === tokenAddress) {
        log('Token already deployed to destination chain', address, tokenInfo.bridged.chainId);
        isTokenAlreadyDeployed = true;
      }
    }

    let estimatedCost;
    try {
      estimatedCost = await estimateCostOfBridging(bridges.ERC20, {
        ...args,
        wallet,
        token: tokenAddress,
        tokenVaultAddress: erc20VaultAddress,
        isTokenAlreadyDeployed,
        tokenObject: token,
      } as ERC20BridgeArgs);
    } catch (err) {
      // TODO: same here. Error code or instance would be better
      if (`${err}`.includes('insufficient allowance')) {
        throw new InsufficientAllowanceError(`insufficient allowance for the amount ${_amount}`, { cause: err });
      } else {
        console.error(err);
      }
    }
    if (!estimatedCost) throw new Error('estimated cost is undefined');
    if (estimatedCost > balance) {
      throw new InsufficientBalanceError('you do not have enough balance to bridge');
    }
  }
}
