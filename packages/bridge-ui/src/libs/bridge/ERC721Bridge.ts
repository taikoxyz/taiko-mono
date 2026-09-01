import { getWalletClient, readContract, simulateContract, writeContract } from '@wagmi/core';
import { getAddress, UserRejectedRequestError } from 'viem';

import { erc721Abi, erc721VaultAbi } from '$abi';
import {
  ApproveError,
  NoApprovalRequiredError,
  NoCanonicalInfoFoundError,
  NotApprovedError,
  SendERC721Error,
} from '$libs/error';
import type { BridgeProver } from '$libs/proof';
import { TokenType } from '$libs/token';
import { getCanonicalInfoForAddress } from '$libs/token/getCanonicalInfoForToken';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { Bridge } from './Bridge';
import { assertNoViolations, checkERC721Message } from './messageInvariants';
import type { ERC721BridgeArgs, NFTApproveArgs, NFTBridgeTransferOp, RequireApprovalArgs } from './types';

const log = getLogger('ERC721Bridge');

export class ERC721Bridge extends Bridge {
  constructor(prover: BridgeProver) {
    super(prover);
  }

  async requiresApproval({ tokenAddress, spenderAddress, tokenId, owner }: RequireApprovalArgs) {
    // No pause check: reading an approval is unaffected by a paused bridge, and the read
    // ran the check against every configured chain on every call. The send path guards
    // itself in _prepareTransaction, which is where a pause actually matters.
    const wallet = await getWalletClient(config);
    const chainId = wallet.chain.id;

    log('Checking approval for token ', tokenId);

    const approvedAddress = await readContract(config, {
      abi: erc721Abi,
      address: tokenAddress,
      functionName: 'getApproved',
      args: [tokenId],
      chainId,
    });

    // Addresses can differ in casing between config and chain, so compare checksummed
    if (getAddress(approvedAddress) === getAddress(spenderAddress)) {
      log(`Token with ID ${tokenId} already approved for ${spenderAddress}`);
      return false;
    }

    // An operator-level approval covers the token as well
    const operator = owner ?? wallet.account.address;
    const isApprovedForAll = await readContract(config, {
      abi: erc721Abi,
      address: tokenAddress,
      functionName: 'isApprovedForAll',
      args: [operator, spenderAddress],
      chainId,
    });
    if (isApprovedForAll) {
      log(`Owner ${operator} has approved ${spenderAddress} for all tokens`);
      return false;
    }

    log(`Token with ID ${tokenId} requires approval for ${spenderAddress}`);
    return true;
  }

  async estimateGas(args: ERC721BridgeArgs): Promise<bigint> {
    const { tokenVaultContract, sendERC721Args } = await ERC721Bridge._prepareTransaction(args);
    const { fee: value } = sendERC721Args;

    log('Estimating gas for sendERC721 call with value', value);

    const estimatedGas = await tokenVaultContract.estimateGas.sendToken([sendERC721Args], { value });

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
    const { destChainId, token, tokenVaultAddress, isTokenAlreadyDeployed, tokenIds, amounts } = args;

    const {
      contract: tokenVaultContract,
      to,
      destOwner,
      gasLimit,
      fee,
      commonFields,
    } = await ERC721Bridge.prepareSend({
      args,
      abi: erc721VaultAbi,
      address: tokenVaultAddress,
      gasEstimate: { isTokenAlreadyDeployed, tokenIds },
    });

    const sendERC721Args = {
      destChainId: BigInt(destChainId),
      to,
      destOwner,
      token,
      gasLimit,
      fee,
      tokenIds: tokenIds.map(BigInt),
      amounts,
    } satisfies NFTBridgeTransferOp;

    log('Preparing transaction with args', sendERC721Args);

    // Refuse a message the bridge is guaranteed to reject, while the reason is still
    // something we can name
    assertNoViolations(
      checkERC721Message({
        ...commonFields,
        tokenAddress: sendERC721Args.token,
        tokenIds: sendERC721Args.tokenIds,
        amounts: sendERC721Args.amounts,
      }),
      'This NFT transfer',
    );

    return { tokenVaultContract, sendERC721Args };
  }
}
