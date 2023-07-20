import { getContract } from '@wagmi/core';

import { tokenVaultABI } from '$abi';
import { bridge } from '$config';
import { getConnectedWallet } from '$libs/util/getConnectedWallet';
import { getLogger } from '$libs/util/logger';

import type { Bridge, ERC20BridgeArgs, SendERC20Args } from './types';

const log = getLogger('ERC20Bridge');

export class ERC20Bridge implements Bridge {
  private static async _prepareTransaction(args: ERC20BridgeArgs) {
    const walletClient = await getConnectedWallet();

    const {
      to,
      memo = '',
      amount,
      destChainId,
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

    const refundAddress = walletClient.account.address;

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

  async estimateGas(args: ERC20BridgeArgs) {
    const { tokenVaultContract, sendERC20Args } = await ERC20Bridge._prepareTransaction(args);
    const [, , , , , processingFee] = sendERC20Args;

    const value = processingFee;

    log('Estimating gas for sendERC20 call. Sending value', value);

    return tokenVaultContract.estimateGas.sendERC20([...sendERC20Args], { value });
  }
}
