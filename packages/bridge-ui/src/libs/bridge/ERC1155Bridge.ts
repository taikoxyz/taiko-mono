import { getPublicClient, simulateContract } from '@wagmi/core';
import { type Address, getContract } from 'viem';

import { erc1155Abi, erc1155VaultAbi } from '$abi';
import { SendERC1155Error } from '$libs/error';
import type { BridgeProver } from '$libs/proof';
import { TokenType } from '$libs/token';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import type { MessageGasEstimateExtras } from './estimateMessageGasLimit';
import { checkERC1155Message } from './messageInvariants';
import { NFTBridge } from './NFTBridge';
import type { ERC1155BridgeArgs, RequireApprovalArgs } from './types';

const log = getLogger('ERC1155Bridge');

export class ERC1155Bridge extends NFTBridge {
  protected readonly standard = 'ERC1155';
  protected readonly tokenType = TokenType.ERC1155;
  protected readonly vaultAbi = erc1155VaultAbi;
  protected readonly log = log;

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

  /** @inheritdoc */
  async requiresApproval(args: RequireApprovalArgs) {
    // ERC1155 has no per-token approval, so the operator approval is the whole answer
    return !(await this.isApprovedForAll(args));
  }

  /** @inheritdoc */
  protected async simulateApproval({
    tokenAddress,
    spenderAddress,
    chainId,
  }: {
    tokenAddress: Address;
    spenderAddress: Address;
    tokenId: bigint;
    chainId: number;
  }) {
    // The whole collection: ERC1155 has no per-token approval to grant
    return simulateContract(config, {
      address: tokenAddress,
      abi: erc1155Abi,
      functionName: 'setApprovalForAll',
      args: [spenderAddress, true],
      chainId,
    });
  }

  /** @inheritdoc */
  protected checkMessage(message: Parameters<typeof checkERC1155Message>[0]) {
    return checkERC1155Message(message);
  }

  /** @inheritdoc */
  protected gasEstimateExtras({
    isTokenAlreadyDeployed,
    tokenIds,
    amounts,
  }: ERC1155BridgeArgs): MessageGasEstimateExtras {
    // The quantities are part of the message, so they count towards its size
    return { isTokenAlreadyDeployed, tokenIds, amounts };
  }

  /** @inheritdoc */
  protected sendError(cause: unknown) {
    return new SendERC1155Error('failed to bridge ERC1155 token', { cause });
  }
}
