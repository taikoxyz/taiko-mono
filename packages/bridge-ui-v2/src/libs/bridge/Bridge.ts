import { getContract, type WalletClient } from '@wagmi/core';
import type { Address, Hash } from 'viem';

import { bridgeABI } from '$abi';
import { chainContractsMap } from '$libs/chain';
import { MessageStatusError, NoOwnerError } from '$libs/error';
import type { Prover } from '$libs/proof';

import { type BridgeArgs, type Message, MessageStatus } from './types';

export abstract class Bridge {
  protected readonly _prover: Prover;

  constructor(prover: Prover) {
    this._prover = prover;
  }

  /**
   * We are gonna run some common checks here:
   * 1. Check that the message is owned by the user
   * 2. Check that the message has not already been processed
   * 3. Check that the message has not failed
   * 4. Check that the message is owned by the user
   *
   * If all fine, we get back the message status and the bridge contract
   * in order to continue with the claim
   */
  async beforeClaiming(msgHash: Hash, ownerAddress: Address, wallet: WalletClient) {
    const userAddress = wallet.account.address;
    if (ownerAddress.toLowerCase() !== userAddress.toLowerCase()) {
      throw new NoOwnerError('user cannot process this as it is not their message');
    }

    const { bridgeAddress } = chainContractsMap[wallet.chain.id];

    const bridgeContract = getContract({
      address: bridgeAddress,
      abi: bridgeABI,

      // Wallet must be connected to the destination chain
      // where the funds will be claimed
      walletClient: wallet,
    });

    const messageStatus: MessageStatus = await bridgeContract.read.getMessageStatus([msgHash]);

    log(`Claiming message with status ${messageStatus}`);

    if (messageStatus === MessageStatus.DONE) {
      throw new MessageStatusError('message already processed');
    }

    if (messageStatus === MessageStatus.FAILED) {
      throw new MessageStatusError('user can not process this as message has failed');
    }

    // We will need these guys to continue with the claim
    return { messageStatus, bridgeContract };
  }

  /**
   * We are gonna run some common checks here:
   * 1. Check that the message is owned by the user
   * 2. Check that the message has failed
   *
   * If all fine, we get back the message status and the bridge contract
   * in order to continue with the release
   */
  async beforeReleasing(msgHash: Hash, ownerAddress: Address, wallet: WalletClient) {
    const userAddress = wallet.account.address;
    if (ownerAddress.toLowerCase() !== userAddress.toLowerCase()) {
      throw new NoOwnerError('user cannot process this as it is not their message');
    }

    const { bridgeAddress } = chainContractsMap[wallet.chain.id];

    const bridgeContract = getContract({
      address: bridgeAddress,
      abi: bridgeABI,

      // Wallet must be connected to the source chain
      // where the funds will be released
      walletClient: wallet,
    });

    const messageStatus: MessageStatus = await bridgeContract.read.getMessageStatus([msgHash]);

    log(`Releasing message with status ${messageStatus}`);

    if (messageStatus !== MessageStatus.FAILED) {
      throw new MessageStatusError('message has not failed');
    }

    // We will need these guys to continue with the claim
    return { messageStatus, bridgeContract };
  }

  abstract estimateGas(args: BridgeArgs): Promise<bigint>;
  abstract bridge(args: BridgeArgs): Promise<Hash>;
  abstract claim(msgHash: Hash, message: Message, wallet: WalletClient): Promise<Hash>;
  abstract release(msgHash: Hash, message: Message, wallet: WalletClient): Promise<Hash>;
}
