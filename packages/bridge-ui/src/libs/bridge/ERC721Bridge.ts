import { readContract, simulateContract } from '@wagmi/core';
import { type Address, getAddress } from 'viem';

import { erc721Abi, erc721VaultAbi } from '$abi';
import { SendERC721Error } from '$libs/error';
import type { BridgeProver } from '$libs/proof';
import { TokenType } from '$libs/token';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import type { MessageGasEstimateExtras } from './estimateMessageGasLimit';
import { checkERC721Message } from './messageInvariants';
import { NFTBridge } from './NFTBridge';
import type { ERC721BridgeArgs, RequireApprovalArgs } from './types';

const log = getLogger('ERC721Bridge');

export class ERC721Bridge extends NFTBridge {
  protected readonly standard = 'ERC721';
  protected readonly tokenType = TokenType.ERC721;
  protected readonly vaultAbi = erc721VaultAbi;
  protected readonly log = log;

  constructor(prover: BridgeProver) {
    super(prover);
  }

  /** @inheritdoc */
  async requiresApproval({ tokenAddress, spenderAddress, tokenId, owner, chainId }: RequireApprovalArgs) {
    // No pause check: reading an approval is unaffected by a paused bridge, and the read
    // ran the check against every configured chain on every call. The send path guards
    // itself in _prepareTransaction, which is where a pause actually matters.
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
    if (!owner) {
      log('No owner given, so the operator approval cannot be read');
      return true;
    }
    const isApprovedForAll = await readContract(config, {
      abi: erc721Abi,
      address: tokenAddress,
      functionName: 'isApprovedForAll',
      args: [owner, spenderAddress],
      chainId,
    });
    if (isApprovedForAll) {
      log(`Owner ${owner} has approved ${spenderAddress} for all tokens`);
      return false;
    }

    log(`Token with ID ${tokenId} requires approval for ${spenderAddress}`);
    return true;
  }

  /** @inheritdoc */
  protected async simulateApproval({
    tokenAddress,
    spenderAddress,
    tokenId,
    chainId,
  }: {
    tokenAddress: Address;
    spenderAddress: Address;
    tokenId: bigint;
    chainId: number;
  }) {
    // A single token, not the whole collection: ERC721Vault only needs this one
    return simulateContract(config, {
      address: tokenAddress,
      abi: erc721Abi,
      functionName: 'approve',
      args: [spenderAddress, tokenId],
      chainId,
    });
  }

  /** @inheritdoc */
  protected checkMessage(message: Parameters<typeof checkERC721Message>[0]) {
    return checkERC721Message(message);
  }

  /** @inheritdoc */
  protected gasEstimateExtras({ isTokenAlreadyDeployed, tokenIds }: ERC721BridgeArgs): MessageGasEstimateExtras {
    // No amounts: every ERC721 amount is zero, so they add nothing to the message size
    return { isTokenAlreadyDeployed, tokenIds };
  }

  /** @inheritdoc */
  protected sendError(cause: unknown) {
    return new SendERC721Error('failed to bridge ERC721 token', { cause });
  }
}
