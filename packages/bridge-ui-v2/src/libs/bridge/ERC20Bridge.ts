import { getContract } from '@wagmi/core';

import { bridgeABI, tokenVaultABI } from '$abi';
import { bridge } from '$config';
import { getLogger } from '$libs/util/logger';

import type { ERC20BridgeArgs, Message, SendERC20Args } from './types';

const log = getLogger('ERC20Bridge');

export class ERC20Bridge {
  private static async _prepareTransaction(args: ERC20BridgeArgs) {
    const {
      to,
      memo = '',
      amount,
      destChainId,
      walletClient,
      tokenAddress,
      processingFee,
      tokenVaultAddress,
      isTokenAlreadyDeployed,
    } = args;

    const tokenVaultContract = getContract({
      walletClient,
      abi: tokenVaultABI,
      address: tokenVaultAddress,
    });

    const refundAddress = walletClient.account.address

    const gasLimit = !isTokenAlreadyDeployed
      ? BigInt(bridge.noTokenDeployedGasLimit)
      : processingFee > 0
      ? bridge.noOwnerGasLimit
      : BigInt(0);

    const sendERC20Args: SendERC20Args = [
      BigInt(destChainId),
      to,
      tokenAddress,
      amount,
      gasLimit,
      processingFee,
      refundAddress,
      memo,
    ];

    log('Preparing transaction with args', sendERC20Args);

    return { tokenVaultContract, sendERC20Args };
  }

  static async estimateGas(args: ERC20BridgeArgs): Promise<bigint> {
    const { tokenVaultContract, sendERC20Args } = await ERC20Bridge._prepareTransaction(args);
    return tokenVaultContract.estimateGas.sendERC20([...sendERC20Args]);
  }
}
