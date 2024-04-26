import { getPublicClient, simulateContract, writeContract } from '@wagmi/core';
import { getContract, UserRejectedRequestError } from 'viem';

import { bridgeAbi, erc1155Abi, erc1155VaultAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { gasLimitConfig } from '$config';
import {
  ApproveError,
  NoApprovalRequiredError,
  NoCanonicalInfoFoundError,
  NotApprovedError,
  SendERC1155Error,
} from '$libs/error';
import type { BridgeProver } from '$libs/proof';
import { TokenType } from '$libs/token';
import { getCanonicalInfoForAddress } from '$libs/token/getCanonicalInfoForToken';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { Bridge } from './Bridge';
import { calculateMessageDataSize } from './calculateMessageDataSize';
import type { ERC1155BridgeArgs, NFTApproveArgs, NFTBridgeTransferOp, RequireApprovalArgs } from './types';

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
      abi: erc1155Abi,
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
        tokenId: BigInt(tokenId),
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

      const { request } = await simulateContract(config, {
        address: tokenVaultContract.address,
        abi: erc1155VaultAbi,
        functionName: 'sendToken',
        //@ts-ignore
        args: [sendERC1155Args],
        value: fee,
      });
      log('Simulate contract', request);

      const tx = await writeContract(config, request);

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

      const { request } = await simulateContract(config, {
        address: tokenAddress,
        abi: erc1155Abi,
        functionName: 'setApprovalForAll',
        args: [spenderAddress, true],
        chainId: wallet.chain.id,
      });
      log('Simulate contract', request);

      const txHash = await writeContract(config, request);

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
      srcChainId,
      destChainId,
      token,
      tokenObject,
      fee,
      tokenVaultAddress,
      isTokenAlreadyDeployed,
      tokenIds,
      amounts,
    } = args;

    if (!wallet || !wallet.account) throw new Error('Wallet is not connected');

    const tokenVaultContract = getContract({
      client: wallet,
      abi: erc1155VaultAbi,
      address: tokenVaultAddress,
    });

    const { size } = await calculateMessageDataSize({ token: tokenObject, chainId: srcChainId, tokenIds, amounts });

    const client = await getPublicClient(config, { chainId: destChainId });
    if (!client) throw new Error('Could not get public client');

    const destBridgeAddress = routingContractsMap[destChainId][srcChainId].bridgeAddress;
    const destBridgeContract = getContract({
      client,
      abi: bridgeAbi,
      address: destBridgeAddress,
    });

    const minGasLimit = await destBridgeContract.read.getMessageMinGasLimit([BigInt(size)]);

    const gasLimit =
      fee === 0n
        ? BigInt(0) // user wants to claim
        : !isTokenAlreadyDeployed
          ? BigInt(minGasLimit) + gasLimitConfig.erc1155DeployedGasLimit // Token is not deployed
          : BigInt(minGasLimit) + gasLimitConfig.erc1155NotDeployedGasLimit; // Token is deployed

    const sendERC1155Args: NFTBridgeTransferOp = {
      destChainId: BigInt(destChainId),
      to,
      destOwner: to,
      token,
      gasLimit: Number(gasLimit),
      fee,
      tokenIds: tokenIds.map(BigInt),
      amounts: amounts.map(BigInt),
    };

    log('Preparing transaction with args', sendERC1155Args);

    return { tokenVaultContract, sendERC1155Args };
  }
}
