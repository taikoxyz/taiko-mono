import { getContract } from '@wagmi/core';
import { type Hash, UserRejectedRequestError } from 'viem';

import { erc1155ABI, erc1155VaultABI } from '$abi';
import { bridgeService } from '$config';
import { ApproveError, NotApprovedError, SendERC1155Error } from '$libs/error';
import type { BridgeProver } from '$libs/proof';
import { getLogger } from '$libs/util/logger';

import { Bridge } from './Bridge';
import type { ERC1155BridgeArgs, NFTApproveArgs, NFTBridgeTransferOp, RequireApprovalArgs } from './types';

const log = getLogger('ERC1155Bridge');

export class ERC1155Bridge extends Bridge {
  constructor(prover: BridgeProver) {
    super(prover);
  }

  async isApprovedForAll({ tokenAddress, spenderAddress, owner }: RequireApprovalArgs) {
    if (!owner) {
      throw new Error('Owner is required for ERC1155 approval check');
    }

    const tokenContract = getContract({
      abi: erc1155ABI,
      address: tokenAddress,
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

    const estimatedGas = tokenVaultContract.estimateGas.sendToken([sendERC1155Args], { value });

    log('Gas estimated', estimatedGas);

    return estimatedGas;
  }

  async bridge(args: ERC1155BridgeArgs) {
    const { token, tokenVaultAddress, tokenIds, wallet } = args;
    const { tokenVaultContract, sendERC1155Args } = await ERC1155Bridge._prepareTransaction(args);
    const { fee: value } = sendERC1155Args;

    // const tokenIdsWithoutApproval: bigint[] = [];

    const tokenId = tokenIds[0]; // TODO: support multiple tokenIds

    const isApprovedForAll = await this.isApprovedForAll({
      tokenAddress: token,
      spenderAddress: tokenVaultAddress,
      tokenId: tokenId,
      owner: wallet.account.address,
    });

    if (!isApprovedForAll) {
      throw new NotApprovedError(`Not approved for all for token`);
    }

    try {
      log('Sending ERC1155 with fee', value);
      log('Sending ERC1155 with args', sendERC1155Args);

      const tx = await tokenVaultContract.write.sendToken([sendERC1155Args], { value });

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

  async claim() {
    return Promise.resolve('0x' as Hash);
  }

  async release() {
    return Promise.resolve('0x' as Hash);
  }

  async approve(args: NFTApproveArgs) {
    const { tokenAddress, spenderAddress, wallet, tokenIds } = args;

    const tokenId = tokenIds[0]; // TODO: support multiple tokenIds

    const isApprovedForAll = await this.isApprovedForAll({
      tokenAddress,
      spenderAddress,
      tokenId: tokenId,
      owner: wallet.account.address,
    });

    log(`Is approved for all: ${isApprovedForAll}`);

    if (!isApprovedForAll) {
      log(`No allowance required for the token ${tokenId}`);
      throw new NotApprovedError(`Not approved for all`);
    }

    const tokenContract = getContract({
      walletClient: wallet,
      abi: erc1155ABI,
      address: tokenAddress,
    });

    try {
      log(`Calling approve for spender "${spenderAddress}" for token`, tokenIds);

      const txHash = await tokenContract.write.setApprovalForAll([spenderAddress, true]);

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
      amount,
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
      amount,
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
