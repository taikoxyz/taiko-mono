import { getContract } from '@wagmi/core';
import { type Hash, UserRejectedRequestError } from 'viem';

import { erc721ABI, erc721VaultABI } from '$abi';
import { bridgeService } from '$config';
import { ApproveError, NotApprovedError, SendERC721Error } from '$libs/error';
import type { BridgeProver } from '$libs/proof';
import { getLogger } from '$libs/util/logger';

import { Bridge } from './Bridge';
import type { ERC721BridgeArgs, NFTApproveArgs, NFTBridgeTransferOp, RequireApprovalArgs } from './types';

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
    const { token, tokenVaultAddress, tokenIds } = args;
    const { tokenVaultContract, sendERC721Args } = await ERC721Bridge._prepareTransaction(args);
    const { fee: value } = sendERC721Args;

    const tokenIdsWithoutApproval: bigint[] = [];
    await Promise.all(
      tokenIds.map(async (tokenId) => {
        try {
          const requireApproval = await this.requiresApproval({
            tokenAddress: token,
            spenderAddress: tokenVaultAddress,
            tokenId: tokenId,
          });

          if (!requireApproval) {
            log(`No allowance required for the token ${tokenId}`);
            return null;
          } else {
            tokenIdsWithoutApproval.push(tokenId);
          }
        } catch (err) {
          throw new SendERC721Error('failed to bridge ERC721 token', { cause: err });
        }
      }),
    );

    if (tokenIdsWithoutApproval.length > 0) {
      log(`Tokens missing approval ${tokenIdsWithoutApproval}`);
      throw new NotApprovedError(`The following tokens are not approved ${tokenIdsWithoutApproval}`);
    }

    try {
      log('Sending ERC721 with fee', value);
      log('Sending ERC721 with args', sendERC721Args);

      const tx = await tokenVaultContract.write.sendToken([sendERC721Args], { value });

      log('ERC721 sent', tx);

      return tx;
    } catch (err) {
      console.error(err);
      if (`${err}`.includes('denied transaction signature')) {
        throw new UserRejectedRequestError(err as Error);
      }
      throw new SendERC721Error('failed to bridge ERC721 token', { cause: err });
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

    const tokenId = tokenIds[0]; //TODO: handle multiple tokenIds
    const requireApproval = await this.requiresApproval({
      tokenAddress,
      spenderAddress,
      tokenId,
    });

    log(`required approval for token ${tokenId}: ${requireApproval}`);

    if (!requireApproval) {
      log(`No allowance required for the token ${tokenId}`);
      throw new Error(`No allowance required for the token ${tokenId}`); // todo: better error
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
      amount,
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
