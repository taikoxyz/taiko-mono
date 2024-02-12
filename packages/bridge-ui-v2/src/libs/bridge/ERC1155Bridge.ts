import { getPublicClient, simulateContract, writeContract } from '@wagmi/core';
import { getContract, type Hash, UserRejectedRequestError } from 'viem';

import { bridgeABI, erc1155ABI, erc1155VaultABI } from '$abi';
import { bridgeService } from '$config';
import {
  ApproveError,
  NoApprovalRequiredError,
  NoCanonicalInfoFoundError,
  NotApprovedError,
  ProcessMessageError,
  SendERC1155Error,
} from '$libs/error';
import type { BridgeProver } from '$libs/proof';
import { TokenType } from '$libs/token';
import { getCanonicalInfoForAddress } from '$libs/token/getCanonicalInfoForToken';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { Bridge } from './Bridge';
import {
  type ClaimArgs,
  type ERC1155BridgeArgs,
  MessageStatus,
  type NFTApproveArgs,
  type NFTBridgeTransferOp,
  type RequireApprovalArgs,
} from './types';

const log = getLogger('ERC1155Bridge');

export class ERC1155Bridge extends Bridge {
  constructor(prover: BridgeProver) {
    super(prover);
  }

  async isApprovedForAll({ tokenAddress, spenderAddress, owner, chainId }: RequireApprovalArgs) {
    if (!owner) {
      throw new Error('Owner is required for ERC1155 approval check');
    }

    const client = await getPublicClient(config, { chainId: chainId });
    if (!client) throw new Error('Could not get public client');

    const tokenContract = getContract({
      abi: erc1155ABI,
      address: tokenAddress,
      client,
    });

    log('Checking approval');
    const isApprovedForAll = await tokenContract.read.isApprovedForAll([owner, spenderAddress]);

    log(` ${spenderAddress} is approved for all: ${isApprovedForAll}`);
    return isApprovedForAll;
  }

  async estimateGas(args: ERC1155BridgeArgs): Promise<bigint> {
    const { tokenVaultContract, sendERC1155Args } = await ERC1155Bridge._prepareTransaction(args);
    const { fee: value } = sendERC1155Args;

    log('Estimating gas for sendERC1155 call with value', value);

    log('Estimating gas for sendERC1155 call with args', sendERC1155Args);

    const estimatedGas = await tokenVaultContract.estimateGas.sendToken([sendERC1155Args], { value });

    log('Gas estimated', estimatedGas);

    return estimatedGas;
  }

  async bridge(args: ERC1155BridgeArgs) {
    const { token, tokenVaultAddress, tokenIds, wallet, srcChainId, destChainId } = args;
    const { tokenVaultContract, sendERC1155Args } = await ERC1155Bridge._prepareTransaction(args);
    const { fee } = sendERC1155Args;

    // const tokenIdsWithoutApproval: bigint[] = [];

    const tokenId = tokenIds[0]; // TODO: support multiple tokenIds

    const info = await getCanonicalInfoForAddress({ address: token, srcChainId, destChainId, type: TokenType.ERC1155 });
    if (!info) throw new NoCanonicalInfoFoundError('No canonical info found for token');
    const { address: canonicalTokenAddress } = info;
    if (!wallet || !wallet.account || !wallet.chain) throw new Error('Wallet is not connected');

    if (canonicalTokenAddress === token) {
      // Token is native, we need to check if we have approval
      const isApprovedForAll = await this.isApprovedForAll({
        tokenAddress: token,
        spenderAddress: tokenVaultAddress,
        tokenId: tokenId,
        owner: wallet.account.address,
        chainId: wallet.chain.id,
      });
      if (!isApprovedForAll) {
        throw new NotApprovedError(`Not approved for all for token`);
      }
    } else {
      log('Token is bridged, no need to check for approval');
    }

    try {
      log('Sending ERC1155 with fee', fee);
      log('Sending ERC1155 with args', sendERC1155Args);

      try {
        const { request } = await simulateContract(config, {
          address: tokenVaultContract.address,
          abi: erc1155VaultABI,
          functionName: 'sendToken',
          args: [sendERC1155Args],
          value: fee,
        });
        log('Simulate contract', request);
      } catch (err) {
        // TODO: Handle error
        console.error(err);
      }

      const tx = await writeContract(config, {
        address: tokenVaultContract.address,
        abi: erc1155VaultABI,
        functionName: 'sendToken',
        args: [sendERC1155Args],
        chainId: wallet.chain.id,
        value: fee,
      });

      log('ERC1155 sent', tx);

      return tx;
    } catch (err) {
      console.error(err);
      if (`${err}`.includes('denied transaction signature')) {
        throw new UserRejectedRequestError(err as Error);
      }
      throw new SendERC1155Error('failed to bridge ERC1155 token', { cause: err });
    }
  }

  async claim(args: ClaimArgs) {
    const { messageStatus, destBridgeAddress } = await super.beforeClaiming(args);
    const { msgHash, message } = args;
    const srcChainId = Number(message.srcChainId);
    const destChainId = Number(message.destChainId);
    let txHash: Hash;
    log('Claiming ERC721 token with message', message);
    log('Message status', messageStatus);
    if (messageStatus === MessageStatus.NEW) {
      const proof = await this._prover.encodedSignalProof(msgHash, srcChainId, destChainId);

      try {
        if (message.gasLimit > bridgeService.erc1155GasLimitThreshold) {
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
          log('Transaction hash for processMessage call', txHash);
        } else {
          //TODO!!!!
          console.error('message.gaslimit  smaller than threshold');
        }
      } catch (err) {
        console.error(err);
        if (`${err}`.includes('denied transaction signature')) {
          throw new UserRejectedRequestError(err as Error);
        }

        throw new ProcessMessageError('failed to process message', { cause: err });
      }
    } else {
      // MessageStatus.RETRIABLE
      //TODO IMPLEMENT RETRY
      // txHash = await super.retryClaim(message, destBridgeContract);
    }
    return Promise.resolve('0x' as Hash);
  }

  async release() {
    //TODO!!!!
    return Promise.resolve('0x' as Hash);
  }

  async approve(args: NFTApproveArgs) {
    const { tokenAddress, spenderAddress, wallet, tokenIds } = args;
    if (!wallet || !wallet.account || !wallet.chain) throw new Error('Wallet is not connected');

    const tokenId = tokenIds[0]; // TODO: support multiple tokenIds

    const isApprovedForAll = await this.isApprovedForAll({
      tokenAddress,
      spenderAddress,
      tokenId: tokenId,
      owner: wallet.account.address,
      chainId: wallet.chain.id,
    });

    log(`Is approved for all: ${isApprovedForAll}`);

    if (isApprovedForAll) {
      log(`No approval required for the token ${tokenId}`);
      throw new NoApprovalRequiredError(`No approval required for the token ${tokenId}`);
    }

    try {
      log(`Calling approve for spender "${spenderAddress}" for token`, tokenIds);

      try {
        const { request } = await simulateContract(config, {
          address: tokenAddress,
          abi: erc1155ABI,
          functionName: 'setApprovalForAll',
          args: [spenderAddress, true],
          chainId: wallet.chain.id,
        });
        log('Simulate contract', request);
      } catch (err) {
        // TODO: Handle error
        console.error(err);
      }

      const txHash = await writeContract(config, {
        address: tokenAddress,
        abi: erc1155ABI,
        functionName: 'setApprovalForAll',
        args: [spenderAddress, true],
        chainId: wallet.chain.id,
      });

      log('Transaction hash for approve call', txHash);

      return txHash;
    } catch (err) {
      console.error(err);

      if (`${err}`.includes('denied transaction signature')) {
        throw new UserRejectedRequestError(err as Error);
      }

      throw new ApproveError('failed to approve ERC1155 token', { cause: err });
    }
  }

  private static async _prepareTransaction(args: ERC1155BridgeArgs) {
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

    if (!wallet || !wallet.account) throw new Error('Wallet is not connected');

    const tokenVaultContract = getContract({
      client: wallet,
      abi: erc1155VaultABI,
      address: tokenVaultAddress,
    });

    const refundTo = wallet.account.address;

    const gasLimit = !isTokenAlreadyDeployed
      ? BigInt(bridgeService.noERC1155TokenDeployedGasLimit)
      : fee > 0
        ? bridgeService.noOwnerGasLimit
        : BigInt(0);

    const sendERC1155Args: NFTBridgeTransferOp = {
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

    log('Preparing transaction with args', sendERC1155Args);

    return { tokenVaultContract, sendERC1155Args };
  }
}
