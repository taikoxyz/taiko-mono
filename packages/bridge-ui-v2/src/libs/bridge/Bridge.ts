import { getContract } from '@wagmi/core';
import type { Hash } from 'viem';

import { bridgeABI } from '$abi';
import { chainContractsMap } from '$libs/chain';
import { MessageStatusError, WrongChainError, WrongOwnerError } from '$libs/error';
import type { Prover } from '$libs/proof';
import { getLogger } from '$libs/util/logger';

import { type BridgeArgs, type ClaimArgs, MessageStatus, type ReleaseArgs } from './types';

const log = getLogger('bridge:Bridge');

export abstract class Bridge {
  protected readonly _prover: Prover;

  constructor(prover: Prover) {
    this._prover = prover;
  }

  /**
   * We are gonna run some common checks here:
   * 1. Check that the wallet is connected to the destination chain
   * 2. Check that the message is owned by the user
   * 3. Check that the message has not already been processed
   * 4. Check that the message has not failed
   * 5. Check that the message is owned by the user
   *
   * Important: wallet must be connected to the destination chain
   */
  async beforeClaiming({ msgHash, message, wallet }: ClaimArgs) {
    const destChainId = Number(message.destChainId);
    if (wallet.chain.id !== destChainId) {
      throw new WrongChainError('wallet must be connected to the destination chain');
    }

    const { owner } = message;
    const userAddress = wallet.account.address;
    if (owner.toLowerCase() !== userAddress.toLowerCase()) {
      throw new WrongOwnerError('user cannot process this as it is not their message');
    }

    const destBridgeAddress = chainContractsMap[wallet.chain.id].bridgeAddress;

    const destBridgeContract = getContract({
      address: destBridgeAddress,
      abi: bridgeABI,
      walletClient: wallet,
    });

    const messageStatus: MessageStatus = await destBridgeContract.read.getMessageStatus([msgHash]);

    log(`Claiming message with status ${messageStatus}`);

    if (messageStatus === MessageStatus.DONE) {
      throw new MessageStatusError('message already processed');
    }

    if (messageStatus === MessageStatus.FAILED) {
      throw new MessageStatusError('user can not process this as message has failed');
    }

    return { messageStatus, destBridgeContract };
  }

  /**
   * We are gonna run the following checks here:
   * 1. Check that the wallet is connected to the source chain
   * 2. Check that the message is owned by the user
   * 3. Check that the message has failed
   */
  async beforeReleasing({ msgHash, message, wallet }: ClaimArgs) {
    const srcChainId = Number(message.srcChainId);
    if (wallet.chain.id !== srcChainId) {
      throw new WrongChainError('wallet must be connected to the source chain');
    }

    const { owner } = message;
    const userAddress = wallet.account.address;
    if (owner.toLowerCase() !== userAddress.toLowerCase()) {
      throw new WrongOwnerError('user cannot process this as it is not their message');
    }

    const destChainId = Number(message.destChainId);
    const destBridgeAddress = chainContractsMap[destChainId].bridgeAddress;

    const destBridgeContract = getContract({
      address: destBridgeAddress,
      abi: bridgeABI,
      chainId: destChainId,
    });

    const messageStatus: MessageStatus = await destBridgeContract.read.getMessageStatus([msgHash]);

    log(`Releasing message with status ${messageStatus}`);

    if (messageStatus !== MessageStatus.FAILED) {
      throw new MessageStatusError('message must fail to release funds');
    }
  }

  abstract estimateGas(args: BridgeArgs): Promise<bigint>;
  abstract bridge(args: BridgeArgs): Promise<Hash>;
  abstract claim(args: ClaimArgs): Promise<Hash>;
  abstract release(args: ReleaseArgs): Promise<Hash>;
}
