import { getContract, type Hash } from '@wagmi/core';
import { UserRejectedRequestError } from 'viem';

import { erc20ABI, tokenVaultABI } from '$abi';
import { bridge } from '$config';
import { ApproveError, InsufficientAllowanceError, NoAllowanceRequiredError, SendERC20Error } from '$libs/error';
import { getLogger } from '$libs/util/logger';

import { MessageStatus, type ApproveArgs, type Bridge, type ClaimArgs, type ERC20BridgeArgs, type RequireAllowanceArgs, type SendERC20Args } from './types';
import { beforeClaiming } from './beforeClaiming';
import { ProofService } from './proofService';

const log = getLogger('ERC20Bridge');

export class ERC20Bridge implements Bridge {
  private static async _prepareTransaction(args: ERC20BridgeArgs) {
    const {
      to,
      amount,
      wallet,
      destChainId,
      tokenAddress,
      processingFee,
      tokenVaultAddress,
      isTokenAlreadyDeployed,
      memo = '',
    } = args;

    const tokenVaultContract = getContract({
      walletClient: wallet,
      abi: tokenVaultABI,
      address: tokenVaultAddress,
    });

    const refundAddress = wallet.account.address;

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

    log('Estimating gas for sendERC20 call with value', value);

    const estimatedGas = tokenVaultContract.estimateGas.sendERC20([...sendERC20Args], { value });

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
    const { amount, tokenAddress, wallet, tokenVaultAddress } = args;

    const requireAllowance = await this.requireAllowance({
      amount,
      tokenAddress,
      ownerAddress: wallet.account.address,
      spenderAddress: tokenVaultAddress,
    });

    if (requireAllowance) {
      throw new InsufficientAllowanceError(`Insufficient allowance for the amount ${amount}`);
    }

    const { tokenVaultContract, sendERC20Args } = await ERC20Bridge._prepareTransaction(args);
    const [, , , , , processingFee] = sendERC20Args;

    const value = processingFee;

    try {
      log('Calling sendERC20 with value', value);

      const txHash = tokenVaultContract.write.sendERC20([...sendERC20Args], { value });

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
    const { msgHash, wallet, message } = args;

    const { messageStatus, bridgeContract } = await beforeClaiming({
      wallet,
      msgHash,
      ownerAddress: message.owner,
    });

    if (messageStatus === MessageStatus.NEW) {
      const proofService = new ProofService();

      const srcChainId = Number(message.srcChainId);
      const destChainId = Number(message.destChainId);
      const srcBridgeAddress = chainContractsMap[srcChainId].bridgeAddress;
      const srcSignalServiceAddress = chainContractsMap[srcChainId].signalServiceAddress;
      const destCrossChainSyncAddress = chainContractsMap[destChainId].crossChainSyncAddress;

      const proofArgs: GenerateProofClaimArgs = {
        msgHash,
        srcChainId,
        destChainId,
        sender: srcBridgeAddress,
        destCrossChainSyncAddress,
        srcSignalServiceAddress,
      };

      log('Generating proof with args', proofArgs);

      const proof = await proofService.generateProofToClaim(proofArgs);

      const txHash = bridgeContract.write.processMessage([message, proof]);

      log('Transaction hash for processMessage call', txHash);

      // TODO: possibly handle unpredictable gas limit error
      //       by trying with a higher gas limit
    } else {
      // MessageStatus.RETRIABLE
      log('Retrying message', message);

      // Last attempt to send the message: isLastAttempt = true
      const txHash = bridgeContract.write.retryMessage([message, true]);

      log('Transaction hash for retryMessage call', txHash);
    }

    return Promise.resolve('0x' as Hash);
  }

  async release() {
    return Promise.resolve('0x' as Hash);
  }
}
