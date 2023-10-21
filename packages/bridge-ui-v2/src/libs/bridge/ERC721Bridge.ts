import { getContract } from '@wagmi/core';
import { type Hash, UserRejectedRequestError } from 'viem';

import { erc721ABI, erc721VaultABI } from '$abi';
import { bridgeService } from '$config';
import {
  ApproveError,
  NoApprovalRequiredError,
  NotApprovedError,
  ProcessMessageError,
  SendERC721Error,
} from '$libs/error';
import type { BridgeProver } from '$libs/proof';
import { getLogger } from '$libs/util/logger';

import { Bridge } from './Bridge';
import {
  type ClaimArgs,
  type ERC721BridgeArgs,
  MessageStatus,
  type NFTApproveArgs,
  type NFTBridgeTransferOp,
  type RequireApprovalArgs,
} from './types';

const log = getLogger('ERC721Bridge');

export class ERC721Bridge extends Bridge {
  constructor(prover: BridgeProver) {
    super(prover);
  }

  async requiresApproval({ tokenAddress, spenderAddress, tokenId }: RequireApprovalArgs) {
    const tokenContract = getContract({
      abi: erc721ABI,
      address: tokenAddress,
    });

    log('Checking approval for token ', tokenId);
    const requiresApproval = (await tokenContract.read.getApproved([tokenId])) !== spenderAddress;

    log(`Token with ID ${tokenId} requires approval ${spenderAddress}: ${requiresApproval}`);
    return requiresApproval;
  }

  async estimateGas(args: ERC721BridgeArgs): Promise<bigint> {
    const { tokenVaultContract, sendERC721Args } = await ERC721Bridge._prepareTransaction(args);
    const { fee: value } = sendERC721Args;

    log('Estimating gas for sendERC721 call with value', value);

    const estimatedGas = tokenVaultContract.estimateGas.sendToken([sendERC721Args], { value });

    log('Gas estimated', estimatedGas);

    return estimatedGas;
  }

  async bridge(args: ERC721BridgeArgs) {
    const { token, tokenVaultAddress, tokenIds, wallet } = args;
    const { tokenVaultContract, sendERC721Args } = await ERC721Bridge._prepareTransaction(args);
    const { fee: value } = sendERC721Args;

    // const tokenIdsWithoutApproval: bigint[] = [];
    const tokenId = tokenIds[0]; //TODO: handle multiple tokenIds

    try {
      const requireApproval = await this.requiresApproval({
        tokenAddress: token,
        spenderAddress: tokenVaultAddress,
        tokenId: tokenId,
        chainId: wallet.chain.id,
      });

      if (requireApproval) {
        throw new NotApprovedError(`The token with id ${tokenId} is not approved for the token vault`);
      }
    } catch (err) {
      throw new SendERC721Error('failed to bridge ERC721 token', { cause: err });
    }

    try {
      log('Sending ERC721 with fee', value);
      log('Sending ERC721 with args', sendERC721Args);

      const txHash = await tokenVaultContract.write.sendToken([sendERC721Args], { value });

      log('Transaction hash for sendERC20 call', txHash);

      return txHash;
    } catch (err) {
      console.error(err);
      if (`${err}`.includes('denied transaction signature')) {
        throw new UserRejectedRequestError(err as Error);
      }
      throw new SendERC721Error('failed to bridge ERC721 token', { cause: err });
    }
  }

  async claim(args: ClaimArgs) {
    const { messageStatus, destBridgeContract } = await super.beforeClaiming(args);
    const { msgHash, message } = args;
    const srcChainId = Number(message.srcChainId);
    const destChainId = Number(message.destChainId);
    let txHash: Hash;
    log('Claiming ERC721 token with message', message);
    log('Message status', messageStatus);
    if (messageStatus === MessageStatus.NEW) {
      const proof = await this._prover.generateProofToProcessMessage(msgHash, srcChainId, destChainId);

      try {
        if (message.gasLimit > bridgeService.erc721GasLimitThreshold) {
          txHash = await destBridgeContract.write.processMessage([message, proof], {
            gas: message.gasLimit,
          });
        } else {
          txHash = await destBridgeContract.write.processMessage([message, proof]);
        }

        log('Transaction hash for processMessage call', txHash);
      } catch (err) {
        console.error(err);
        if (`${err}`.includes('denied transaction signature')) {
          throw new UserRejectedRequestError(err as Error);
        }

        throw new ProcessMessageError('failed to process message', { cause: err });
      }
    } else {
      // MessageStatus.RETRIABLE
      txHash = await super.retryClaim(message, destBridgeContract);
    }
    return Promise.resolve('0x' as Hash);
  }

  async release() {
    return Promise.resolve('0x' as Hash);
  }

  async approve(args: NFTApproveArgs) {
    const { tokenAddress, spenderAddress, wallet, tokenIds } = args;

    const tokenId = tokenIds[0]; //TODO: handle multiple tokenIds

    const requireApproval = await this.requiresApproval({
      tokenAddress,
      spenderAddress,
      tokenId,
      chainId: wallet.chain.id,
    });

    log(`required approval for token ${tokenId}: ${requireApproval}`);

    if (!requireApproval) {
      log(`No approval required for the token ${tokenId}`);
      throw new NoApprovalRequiredError(`No approval required for the token ${tokenId}`);
    }

    const tokenContract = getContract({
      walletClient: wallet,
      abi: erc721ABI,
      address: tokenAddress,
    });

    try {
      log(`Calling approve for spender "${spenderAddress}" for token`, tokenIds);

      const txHash = await tokenContract.write.approve([spenderAddress, tokenId]);

      log('Transaction hash for approve call', txHash);

      return txHash;
    } catch (err) {
      console.error(err);

      if (`${err}`.includes('denied transaction signature')) {
        throw new UserRejectedRequestError(err as Error);
      }

      throw new ApproveError('failed to approve ERC721 token', { cause: err });
    }
  }

  private static async _prepareTransaction(args: ERC721BridgeArgs) {
    const {
      to,
      wallet,
      destChainId,
      token,
      fee,
      tokenVaultAddress,
      isTokenAlreadyDeployed,
      memo = '',
      tokenIds,
      amounts,
    } = args;

    const tokenVaultContract = getContract({
      walletClient: wallet,
      abi: erc721VaultABI,
      address: tokenVaultAddress,
    });

    const refundTo = wallet.account.address;

    const gasLimit = !isTokenAlreadyDeployed
      ? BigInt(bridgeService.noERC721TokenDeployedGasLimit)
      : fee > 0
      ? bridgeService.noOwnerGasLimit
      : BigInt(0);

    const sendERC721Args: NFTBridgeTransferOp = {
      destChainId: BigInt(destChainId),
      to,
      token,
      gasLimit,
      fee,
      refundTo,
      memo,
      tokenIds,
      amounts,
    };

    log('Preparing transaction with args', sendERC721Args);

    return { tokenVaultContract, sendERC721Args };
  }
}
