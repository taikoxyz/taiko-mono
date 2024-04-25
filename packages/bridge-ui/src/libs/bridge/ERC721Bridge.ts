import { getPublicClient, getWalletClient, readContract, simulateContract, writeContract } from '@wagmi/core';
import { getContract, UserRejectedRequestError } from 'viem';

import { bridgeAbi, erc721Abi, erc721VaultAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { gasLimitConfig } from '$config';
import {
  ApproveError,
  BridgePausedError,
  NoApprovalRequiredError,
  NoCanonicalInfoFoundError,
  NotApprovedError,
  SendERC721Error,
} from '$libs/error';
import type { BridgeProver } from '$libs/proof';
import { TokenType } from '$libs/token';
import { getCanonicalInfoForAddress } from '$libs/token/getCanonicalInfoForToken';
import { isBridgePaused } from '$libs/util/checkForPausedContracts';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { Bridge } from './Bridge';
import { calculateMessageDataSize } from './calculateMessageDataSize';
import type { ERC721BridgeArgs, NFTApproveArgs, NFTBridgeTransferOp, RequireApprovalArgs } from './types';

const log = getLogger('ERC721Bridge');

export class ERC721Bridge extends Bridge {
  constructor(prover: BridgeProver) {
    super(prover);
  }

  async requiresApproval({ tokenAddress, spenderAddress, tokenId }: RequireApprovalArgs) {
    isBridgePaused().then((paused) => {
      if (paused) throw new BridgePausedError('Bridge is paused');
    });

    const chainId = (await getWalletClient(config)).chain.id;

    log('Checking approval for token ', tokenId);

    const approvedAddress = await readContract(config, {
      abi: erc721Abi,
      address: tokenAddress,
      functionName: 'getApproved',
      args: [tokenId],
      chainId,
    });
    const requiresApproval = approvedAddress !== spenderAddress;
    log(`Token with ID ${tokenId} requires approval ${spenderAddress}: ${requiresApproval}`);
    return requiresApproval;
  }

  async estimateGas(args: ERC721BridgeArgs): Promise<bigint> {
    isBridgePaused().then((paused) => {
      if (paused) throw new BridgePausedError('Bridge is paused');
    });

    const { tokenVaultContract, sendERC721Args } = await ERC721Bridge._prepareTransaction(args);
    const { fee: value } = sendERC721Args;

    log('Estimating gas for sendERC721 call with value', value);

    const estimatedGas = tokenVaultContract.estimateGas.sendToken([sendERC721Args], { value });

    log('Gas estimated', estimatedGas);

    return estimatedGas;
  }

  async bridge(args: ERC721BridgeArgs) {
    const { token, tokenVaultAddress, tokenIds, wallet, srcChainId, destChainId } = args;

    const { tokenVaultContract, sendERC721Args } = await ERC721Bridge._prepareTransaction(args);
    const { fee } = sendERC721Args;

    // const tokenIdsWithoutApproval: bigint[] = [];
    const tokenId = tokenIds[0]; //TODO: handle multiple tokenIds

    try {
      const info = await getCanonicalInfoForAddress({
        address: token,
        srcChainId,
        destChainId,
        type: TokenType.ERC721,
      });
      if (!info) throw new NoCanonicalInfoFoundError('No canonical info found for token');
      const { address: canonicalTokenAddress } = info;
      if (!wallet || !wallet.account || !wallet.chain) throw new Error('Wallet is not connected');

      if (canonicalTokenAddress === token) {
        // Token is native, we need to check if we have approval
        const requireApproval = await this.requiresApproval({
          tokenAddress: token,
          spenderAddress: tokenVaultAddress,
          tokenId: BigInt(tokenId),
          chainId: wallet.chain.id,
        });
        if (requireApproval) {
          throw new NotApprovedError(`The token with id ${tokenId} is not approved for the token vault`);
        }
      } else {
        log('Token is bridged, no need to check for approval');
      }
    } catch (err) {
      throw new SendERC721Error('failed to bridge ERC721 token', { cause: err });
    }

    try {
      log('Sending ERC721 with fee', fee);
      log('Sending ERC721 with args', sendERC721Args);

      const { request } = await simulateContract(config, {
        address: tokenVaultContract.address,
        abi: erc721VaultAbi,
        functionName: 'sendToken',
        //@ts-ignore
        args: [sendERC721Args],
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
      throw new SendERC721Error('failed to bridge ERC721 token', { cause: err });
    }
  }

  async approve(args: NFTApproveArgs) {
    const { tokenAddress, spenderAddress, wallet, tokenIds } = args;

    const tokenId = tokenIds[0]; //TODO: handle multiple tokenIds

    if (!wallet || !wallet.account || !wallet.chain) throw new Error('Wallet is not connected');
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

    try {
      log(`Calling approve for spender "${spenderAddress}" for token`, tokenIds);

      const { request } = await simulateContract(config, {
        address: tokenAddress,
        abi: erc721Abi,
        functionName: 'approve',
        args: [spenderAddress, tokenId],
        chainId: wallet.chain.id,
      });
      log('Simulate contract', request);

      const txHash = await writeContract(config, request);

      log('Transaction hash for approve call', txHash);

      return txHash;
    } catch (err) {
      // TODO: Handle error
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
      srcChainId,
      destChainId,
      tokenObject,
      token,
      fee,
      tokenVaultAddress,
      isTokenAlreadyDeployed,
      tokenIds,
      amounts,
    } = args;

    const tokenVaultContract = getContract({
      client: wallet,
      abi: erc721VaultAbi,
      address: tokenVaultAddress,
    });

    if (!wallet || !wallet.account) throw new Error('Wallet is not connected');

    const { size } = await calculateMessageDataSize({ token: tokenObject, chainId: srcChainId, tokenIds });

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
          ? BigInt(minGasLimit) + gasLimitConfig.erc721NotDeployedGasLimit // Token is not deployed
          : BigInt(minGasLimit) + gasLimitConfig.erc721DeployedGasLimit; // Token is deployed

    const sendERC721Args: NFTBridgeTransferOp = {
      destChainId: BigInt(destChainId),
      to,
      destOwner: to,
      token,
      gasLimit: Number(gasLimit),
      fee,
      tokenIds: tokenIds.map(BigInt),
      amounts: amounts.map(BigInt),
    } satisfies NFTBridgeTransferOp;

    log('Preparing transaction with args', sendERC721Args);

    return { tokenVaultContract, sendERC721Args };
  }
}
