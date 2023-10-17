import { getContract, type Hash } from '@wagmi/core';
import { UserRejectedRequestError } from 'viem';

import { bridgeABI, erc20ABI, erc20VaultABI } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { bridgeService } from '$config';
import {
  ApproveError,
  InsufficientAllowanceError,
  NoAllowanceRequiredError,
  ProcessMessageError,
  ReleaseError,
  SendERC20Error,
} from '$libs/error';
import type { BridgeProver } from '$libs/proof';
import { getLogger } from '$libs/util/logger';

import { Bridge } from './Bridge';
import {
  type ApproveArgs,
  type BridgeTransferOp,
  type ClaimArgs,
  type ERC20BridgeArgs,
  MessageStatus,
  type ReleaseArgs,
  type RequireAllowanceArgs,
} from './types';

const log = getLogger('ERC20Bridge');

export class ERC20Bridge extends Bridge {
  private static async _prepareTransaction(args: ERC20BridgeArgs) {
    const { to, amount, wallet, destChainId, token, fee, tokenVaultAddress, isTokenAlreadyDeployed, memo = '' } = args;

    const tokenVaultContract = getContract({
      walletClient: wallet,
      abi: erc20VaultABI,
      address: tokenVaultAddress,
    });

    const refundTo = wallet.account.address;

    const gasLimit = !isTokenAlreadyDeployed
      ? BigInt(bridgeService.noERC20TokenDeployedGasLimit)
      : fee > 0
      ? bridgeService.noOwnerGasLimit
      : BigInt(0);

    const sendERC20Args: BridgeTransferOp = {
      destChainId: BigInt(destChainId),
      to,
      token,
      amount,
      gasLimit,
      fee,
      refundTo,
      memo,
    };

    log('Preparing transaction with args', sendERC20Args);

    return { tokenVaultContract, sendERC20Args };
  }

  constructor(prover: BridgeProver) {
    super(prover);
  }

  async estimateGas(args: ERC20BridgeArgs) {
    const { tokenVaultContract, sendERC20Args } = await ERC20Bridge._prepareTransaction(args);
    const { fee } = sendERC20Args;

    const value = fee;

    log('Estimating gas for sendERC20 call with value', value);

    const estimatedGas = tokenVaultContract.estimateGas.sendToken([sendERC20Args], { value });

    log('Gas estimated', estimatedGas);

    return estimatedGas;
  }

  async requireAllowance({ amount, tokenAddress, ownerAddress, spenderAddress }: RequireAllowanceArgs) {
    const tokenContract = getContract({
      abi: erc20ABI,
      address: tokenAddress,
    });

    log('Checking allowance for the amount', amount);

    const allowance = await tokenContract.read.allowance([ownerAddress, spenderAddress]);

    const requiresAllowance = allowance < amount;

    log('Allowance is', allowance, 'requires allowance?', requiresAllowance);

    return requiresAllowance;
  }

  async approve(args: ApproveArgs) {
    const { amount, tokenAddress, spenderAddress, wallet } = args;

    const requireAllowance = await this.requireAllowance({
      amount,
      tokenAddress,
      ownerAddress: wallet.account.address,
      spenderAddress,
    });

    if (!requireAllowance) {
      throw new NoAllowanceRequiredError(`no allowance required for the amount ${amount}`);
    }

    const tokenContract = getContract({
      walletClient: wallet,
      abi: erc20ABI,
      address: tokenAddress,
    });

    try {
      log(`Calling approve for spender "${spenderAddress}" with amount`, amount);

      const txHash = await tokenContract.write.approve([spenderAddress, amount]);

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
    const { fee: value } = sendERC20Args;

    try {
      log('Calling sendERC20 with value', value);

      const txHash = await tokenVaultContract.write.sendToken([sendERC20Args], { value });

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

  async claim(args: ClaimArgs) {
    const { messageStatus, destBridgeContract } = await super.beforeClaiming(args);

    let txHash: Hash;
    const { msgHash, message } = args;
    const srcChainId = Number(message.srcChainId);
    const destChainId = Number(message.destChainId);

    if (messageStatus === MessageStatus.NEW) {
      const proof = await this._prover.generateProofToProcessMessage(msgHash, srcChainId, destChainId);

      try {
        if (message.gasLimit > bridgeService.erc20GasLimitThreshold) {
          txHash = await destBridgeContract.write.processMessage([message, proof], {
            gas: message.gasLimit,
          });
        } else {
          txHash = await destBridgeContract.write.processMessage([message, proof]);
        }

        log('Transaction hash for processMessage call', txHash);
      } catch (err) {
        console.error(err);

        // TODO: possibly same logic as ETHBridge

        // TODO: handle unpredictable gas limit error
        //       by trying with a higher gas limit

        if (`${err}`.includes('denied transaction signature')) {
          throw new UserRejectedRequestError(err as Error);
        }

        throw new ProcessMessageError('failed to process message', { cause: err });
      }
    } else {
      // MessageStatus.RETRIABLE
      txHash = await super.retryClaim(message, destBridgeContract);
    }

    return txHash;
  }

  async release(args: ReleaseArgs) {
    await super.beforeReleasing(args);

    const { msgHash, message, wallet } = args;
    const srcChainId = Number(message.srcChainId);
    const destChainId = Number(message.destChainId);
    const connectedChainId = await wallet.getChainId();

    const proof = await this._prover.generateProofToRelease(msgHash, srcChainId, destChainId);

    const bridgeAddress = routingContractsMap[connectedChainId][destChainId].bridgeAddress;
    const bridgeContract = getContract({
      walletClient: wallet,
      abi: bridgeABI,
      address: bridgeAddress,
    });

    try {
      const txHash = await bridgeContract.write.recallMessage([message, proof]);

      log('Transaction hash for releaseERC20 call', txHash);

      return txHash;
    } catch (err) {
      console.error(err);

      if (`${err}`.includes('denied transaction signature')) {
        throw new UserRejectedRequestError(err as Error);
      }

      throw new ReleaseError('failed to release ERC20', { cause: err });
    }
  }
}
