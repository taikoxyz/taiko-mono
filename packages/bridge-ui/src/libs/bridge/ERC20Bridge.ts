import { readContract, simulateContract, writeContract } from '@wagmi/core';
import { getContract, type Hash, UserRejectedRequestError } from 'viem';

import { bridgeABI, erc20ABI, erc20VaultABI } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { bridgeService } from '$config';
import {
  ApproveError,
  BridgePausedError,
  InsufficientAllowanceError,
  NoAllowanceRequiredError,
  NoTokenInfoFoundError,
  ProcessMessageError,
  ReleaseError,
  SendERC20Error,
} from '$libs/error';
import type { BridgeProver } from '$libs/proof';
import { TokenType } from '$libs/token';
import { getTokenAddressesForAddress } from '$libs/token/getTokenAddresses';
import { isBridgePaused } from '$libs/util/checkForPausedContracts';
import { getConnectedWallet } from '$libs/util/getConnectedWallet';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

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
    if (!wallet || !wallet.account) throw new Error('No wallet found');

    const tokenVaultContract = getContract({
      client: wallet,
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
    isBridgePaused().then((paused) => {
      if (paused) throw new BridgePausedError('Bridge is paused');
    });

    const { tokenVaultContract, sendERC20Args } = await ERC20Bridge._prepareTransaction(args);
    const { fee } = sendERC20Args;

    const value = fee;

    log('Estimating gas for sendERC20 call with value', value);

    const estimatedGas = await tokenVaultContract.estimateGas.sendToken([sendERC20Args], { value });

    log('Gas estimated', estimatedGas);

    return estimatedGas;
  }

  async requireAllowance({ amount, tokenAddress, ownerAddress, spenderAddress }: RequireAllowanceArgs) {
    isBridgePaused().then((paused) => {
      if (paused) throw new BridgePausedError('Bridge is paused');
    });

    log('Checking allowance for the amount', amount);
    const allowance = await readContract(config, {
      abi: erc20ABI,
      address: tokenAddress,
      functionName: 'allowance',
      args: [ownerAddress, spenderAddress],
      chainId: (await getConnectedWallet()).chain.id,
    });

    const requiresAllowance = allowance < amount;

    log('Allowance is', allowance, 'requires allowance?', requiresAllowance);

    return requiresAllowance;
  }

  async approve(args: ApproveArgs) {
    const { amount, tokenAddress, spenderAddress, wallet } = args;
    if (!wallet || !wallet.account) throw new Error('No wallet found');
    const requireAllowance = await this.requireAllowance({
      amount,
      tokenAddress,
      ownerAddress: wallet.account.address,
      spenderAddress,
    });

    if (!requireAllowance) {
      throw new NoAllowanceRequiredError(`no allowance required for the amount ${amount}`);
    }

    try {
      log(`Calling approve for spender "${spenderAddress}" for token "${tokenAddress}" with amount`, amount);

      const { request } = await simulateContract(config, {
        address: tokenAddress,
        abi: erc20ABI,
        functionName: 'approve',
        args: [spenderAddress, amount],
      });
      log('Simulate contract', request);

      if (!wallet || !wallet.account || !wallet.chain) throw new Error('Wallet is not connected');

      const txHash = await writeContract(config, {
        address: tokenAddress,
        abi: erc20ABI,
        functionName: 'approve',
        args: [spenderAddress, amount],
        chainId: wallet.chain.id,
      });

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
    const { amount, token, wallet, tokenVaultAddress, srcChainId, destChainId } = args;
    const type = TokenType.ERC20;
    const info = await getTokenAddressesForAddress({ address: token, srcChainId, destChainId, type });

    if (!info) throw new NoTokenInfoFoundError(`Could not find any token info for ${token}`);

    const { canonical } = info;
    const canonicalTokenAddress = canonical?.address;
    if (!wallet || !wallet.account || !wallet.chain) throw new Error('Wallet is not connected');

    if (canonicalTokenAddress === token) {
      // Token is native, we need to check if we have approval
      const requireAllowance = await this.requireAllowance({
        amount,
        tokenAddress: token,
        ownerAddress: wallet.account.address,
        spenderAddress: tokenVaultAddress,
      });

      if (requireAllowance) {
        throw new InsufficientAllowanceError(`Insufficient allowance for the amount ${amount}`);
      }
    } else {
      log('Token is bridged, no need to check for approval');
    }

    const { tokenVaultContract, sendERC20Args } = await ERC20Bridge._prepareTransaction(args);
    const { fee } = sendERC20Args;

    try {
      log('Calling sendERC20 with value', fee);

      const { request } = await simulateContract(config, {
        address: tokenVaultContract.address,
        abi: erc20VaultABI,
        functionName: 'sendToken',
        args: [sendERC20Args],
        value: fee,
      });
      log('Simulate contract', request);

      const txHash = await writeContract(config, {
        address: tokenVaultContract.address,
        abi: erc20VaultABI,
        functionName: 'sendToken',
        args: [sendERC20Args],
        chainId: wallet.chain.id,
        value: fee,
      });

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
    const { messageStatus, destBridgeAddress } = await super.beforeClaiming(args);

    let txHash: Hash;
    const { msgHash, message } = args;
    const srcChainId = Number(message.srcChainId);
    const destChainId = Number(message.destChainId);

    if (messageStatus === MessageStatus.NEW) {
      const proof = await this._prover.encodedSignalProof(msgHash, srcChainId, destChainId);

      try {
        if (message.gasLimit > bridgeService.erc20GasLimitThreshold) {
          const { request } = await simulateContract(config, {
            address: destBridgeAddress,
            abi: bridgeABI,
            functionName: 'processMessage',
            args: [message, proof],
            gas: message.gasLimit,
          });
          log('Simulate contract', request);

          txHash = await writeContract(config, {
            address: destBridgeAddress,
            abi: bridgeABI,
            functionName: 'processMessage',
            args: [message, proof],
            gas: message.gasLimit,
          });
        } else {
          const { request } = await simulateContract(config, {
            address: destBridgeAddress,
            abi: bridgeABI,
            functionName: 'processMessage',
            args: [message, proof],
          });
          log('Simulate contract', request);

          txHash = await writeContract(config, {
            address: destBridgeAddress,
            abi: bridgeABI,
            functionName: 'processMessage',
            args: [message, proof],
          });
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
      //TODO IMPLEMENT RETRY
      throw new Error('Not implemented');
      // txHash = await super.retryClaim(message, destBridgeContract);
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
    if (!wallet || !wallet.account || !wallet.chain) throw new Error('Wallet is not connected');

    try {
      const { request } = await simulateContract(config, {
        address: bridgeAddress,
        abi: bridgeABI,
        functionName: 'recallMessage',
        args: [message, proof],
      });
      log('Simulate contract', request);

      const txHash = await writeContract(config, {
        address: bridgeAddress,
        abi: bridgeABI,
        functionName: 'recallMessage',
        args: [message, proof],
        chainId: wallet.chain.id,
      });
      // const txHash = await bridgeContract.write.recallMessage([message, proof]);

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
