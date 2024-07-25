import { getPublicClient, readContract, simulateContract, writeContract } from '@wagmi/core';
import { get } from 'svelte/store';
import { getContract, UserRejectedRequestError } from 'viem';

import { bridgeAbi, erc20Abi, erc20VaultAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { destOwnerAddress, gasLimitZero } from '$components/Bridge/state';
import { gasLimitConfig } from '$config';
import {
  ApproveError,
  BridgePausedError,
  InsufficientAllowanceError,
  NoAllowanceRequiredError,
  SendERC20Error,
} from '$libs/error';
import type { BridgeProver } from '$libs/proof';
import { isBridgePaused } from '$libs/util/checkForPausedContracts';
import { getConnectedWallet } from '$libs/util/getConnectedWallet';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { Bridge } from './Bridge';
import { calculateMessageDataSize } from './calculateMessageDataSize';
import type { ApproveArgs, BridgeTransferOp, ERC20BridgeArgs, RequireAllowanceArgs } from './types';

const log = getLogger('ERC20Bridge');

export class ERC20Bridge extends Bridge {
  private static async _prepareTransaction(args: ERC20BridgeArgs) {
    const {
      to,
      amount,
      wallet,
      srcChainId,
      destChainId,
      token,
      tokenObject,
      fee,
      tokenVaultAddress,
      isTokenAlreadyDeployed,
    } = args;
    if (!wallet || !wallet.account) throw new Error('No wallet found');

    const tokenVaultContract = getContract({
      client: wallet,
      abi: erc20VaultAbi,
      address: tokenVaultAddress,
    });

    const { size } = await calculateMessageDataSize({ token: tokenObject, chainId: srcChainId });

    const client = await getPublicClient(config, { chainId: destChainId });
    if (!client) throw new Error('Could not get public client');

    const destBridgeAddress = routingContractsMap[destChainId][srcChainId].bridgeAddress;
    const destBridgeContract = getContract({
      client,
      abi: bridgeAbi,
      address: destBridgeAddress,
    });

    const minGasLimit = await destBridgeContract.read.getMessageMinGasLimit([BigInt(size)]);

    let gasLimit: number;
    if (get(gasLimitZero)) {
      log('Gas limit is set to 0');
      gasLimit = 0;
    } else {
      gasLimit = !isTokenAlreadyDeployed
        ? minGasLimit + gasLimitConfig.erc20NotDeployedGasLimit // Token is not deployed
        : minGasLimit + gasLimitConfig.erc20DeployedGasLimit; // Token is deployed
    }

    log('Calculated gasLimit for message', gasLimit);

    const sendERC20Args = {
      destChainId: BigInt(destChainId),
      destOwner: get(destOwnerAddress) || to,
      to,
      token,
      amount,
      gasLimit: Number(gasLimit),
      fee,
    } satisfies BridgeTransferOp;

    log('Preparing transaction with args', sendERC20Args);

    return { tokenVaultContract, sendERC20Args };
  }

  constructor(prover: BridgeProver) {
    super(prover);
  }

  async estimateGas(args: ERC20BridgeArgs) {
    isBridgePaused().then((paused) => {
      if (paused) throw new BridgePausedError('Bridge is paused');
    });

    const { tokenVaultContract, sendERC20Args } = await ERC20Bridge._prepareTransaction(args as ERC20BridgeArgs);
    const { fee } = sendERC20Args;

    const value = fee;

    log('Estimating gas for sendERC20 call with value', value);

    const estimatedGas = await tokenVaultContract.estimateGas.sendToken([sendERC20Args], { value });

    log('Gas estimated', estimatedGas);

    return estimatedGas;
  }

  async getAllowance({ amount, tokenAddress, ownerAddress, spenderAddress }: RequireAllowanceArgs) {
    isBridgePaused().then((paused) => {
      if (paused) throw new BridgePausedError('Bridge is paused');
    });

    log('Checking allowance for the amount', amount);
    const allowance = await readContract(config, {
      abi: erc20Abi,
      address: tokenAddress,
      functionName: 'allowance',
      args: [ownerAddress, spenderAddress],
      chainId: (await getConnectedWallet()).chain.id,
    });

    return allowance;
  }
  async requireAllowance({ amount, tokenAddress, ownerAddress, spenderAddress }: RequireAllowanceArgs, reset = false) {
    const allowance = await this.getAllowance({ amount, tokenAddress, ownerAddress, spenderAddress });

    if (reset) {
      return true;
    }
    const requiresAllowance = allowance < amount;

    log('Allowance is', allowance, 'requires allowance?', requiresAllowance);

    return requiresAllowance;
  }

  async approve(args: ApproveArgs, reset = false) {
    const { amount, tokenAddress, spenderAddress, wallet } = args;
    if (!wallet || !wallet.account) throw new Error('No wallet found');
    const requireAllowance = await this.requireAllowance(
      {
        amount,
        tokenAddress,
        ownerAddress: wallet.account.address,
        spenderAddress,
      },
      reset,
    );

    if (!requireAllowance) {
      throw new NoAllowanceRequiredError(`no allowance required for the amount ${amount}`);
    }

    try {
      log(`Calling approve for spender "${spenderAddress}" for token "${tokenAddress}" with amount`, amount);
      // USDT does not play nice with the default ERC20 ABI, this works for both
      const approvalABI = [
        {
          constant: false,
          inputs: [
            {
              name: '_spender',
              type: 'address',
            },
            {
              name: '_value',
              type: 'uint256',
            },
          ],
          name: 'approve',
          outputs: [],
          payable: false,
          stateMutability: 'nonpayable',
          type: 'function',
        },
      ];

      const { request } = await simulateContract(config, {
        address: tokenAddress,
        abi: approvalABI,
        functionName: 'approve',
        args: [spenderAddress, amount],
      });
      log('Simulate contract', request);

      if (!wallet || !wallet.account || !wallet.chain) throw new Error('Wallet is not connected');

      const txHash = await writeContract(config, request);

      log('Transaction hash for approve call', txHash);

      return txHash;
    } catch (err) {
      console.error(err);

      if (`${err}`.includes('denied transaction signature')) {
        throw new UserRejectedRequestError(err as Error);
      }

      throw new ApproveError('failed to approve ERC20 token', { cause: err });
    }
  }

  async bridge(args: ERC20BridgeArgs) {
    const { amount, token, wallet, tokenVaultAddress } = args;

    if (!wallet || !wallet.account || !wallet.chain) throw new Error('Wallet is not connected');

    const requireAllowance = await this.requireAllowance({
      amount,
      tokenAddress: token,
      ownerAddress: wallet.account.address,
      spenderAddress: tokenVaultAddress,
    });

    if (requireAllowance) {
      throw new InsufficientAllowanceError(`Insufficient allowance for the amount ${amount}`);
    }

    const { tokenVaultContract, sendERC20Args } = await ERC20Bridge._prepareTransaction(args);
    const { fee } = sendERC20Args;

    try {
      const { request } = await simulateContract(config, {
        address: tokenVaultContract.address,
        abi: erc20VaultAbi,
        functionName: 'sendToken',
        args: [sendERC20Args],
        value: fee,
      });
      log('Simulate contract', request);

      const txHash = await writeContract(config, request);

      log('Transaction hash for sendERC20 call', txHash);

      return txHash;
    } catch (err) {
      console.error(err);

      if (`${err}`.includes('denied transaction signature')) {
        throw new UserRejectedRequestError(err as Error);
      }

      throw new SendERC20Error('failed to bridge ERC20 token', { cause: err });
    }
  }
}
