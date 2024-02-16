import { readContract } from '@wagmi/core';
import type { Hash } from 'viem';

import { bridgeABI } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { MessageStatusError, WrongChainError, WrongOwnerError } from '$libs/error';
import type { BridgeProver } from '$libs/proof';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { type BridgeArgs, type ClaimArgs, MessageStatus, type ReleaseArgs } from './types';

const log = getLogger('bridge:Bridge');

export abstract class Bridge {
  protected readonly _prover: BridgeProver;

  constructor(prover: BridgeProver) {
    this._prover = prover;
  }

  /**
   * We are gonna run some common checks here:
   * 1. Check that the wallet is connected to the destination chain
   * 2. Check that the message is owned by the user
   * 3. Check that the message has not been claimed already
   * 4. Check that the message has not failed
   *
   * Important: wallet must be connected to the destination chain
   */
  protected async beforeClaiming({ msgHash, message, wallet }: ClaimArgs) {
    const connectedChainId = await wallet.getChainId();
    const destChainId = Number(message.destChainId);
    const srcChainId = Number(message.srcChainId);
    // Are we connected to the destination chain?
    if (connectedChainId !== destChainId) {
      throw new WrongChainError('wallet must be connected to the destination chain');
    }

    const { owner } = message;
    if (!wallet || !wallet.account || !wallet.chain) throw new Error('Wallet is not connected');

    const userAddress = wallet.account.address;
    // Are we the owner of the message?
    if (owner.toLowerCase() !== userAddress.toLowerCase()) {
      throw new WrongOwnerError('user cannot process this as it is not their message');
    }

    const destBridgeAddress = routingContractsMap[connectedChainId][srcChainId].bridgeAddress;

    const messageStatus = await readContract(config, {
      address: destBridgeAddress,
      abi: bridgeABI,
      functionName: 'messageStatus',
      args: [msgHash],
      chainId: connectedChainId,
    });

    log(`Claiming message with status ${messageStatus}`);

    // Has it been claimed already?
    if (messageStatus === MessageStatus.DONE) {
      throw new MessageStatusError('message already processed');
    }

    // Has it failed?
    if (messageStatus === MessageStatus.FAILED) {
      throw new MessageStatusError('user can not process this as message has failed');
    }

    return { messageStatus, destBridgeAddress };
  }

  /**
   * We are gonna run the following checks here:
   * 1. Check that the wallet is connected to the source chain
   * 2. Check that the message is owned by the user
   * 3. Check that the message has failed
   */
  protected async beforeReleasing({ msgHash, message, wallet }: ClaimArgs) {
    const connectedChainId = await wallet.getChainId();
    const srcChainId = Number(message.srcChainId);
    // Are we connected to the source chain?
    if (connectedChainId !== srcChainId) {
      throw new WrongChainError('wallet must be connected to the source chain');
    }

    const { owner } = message;
    if (!wallet || !wallet.account || !wallet.chain) throw new Error('Wallet is not connected');

    const userAddress = wallet.account.address;
    // Are we the owner of the message?
    if (owner.toLowerCase() !== userAddress.toLowerCase()) {
      throw new WrongOwnerError('user cannot process this as it is not their message');
    }

    // Before releasing we need to make sure the message has failed
    const destChainId = Number(message.destChainId);
    const destBridgeAddress = routingContractsMap[destChainId][srcChainId].bridgeAddress;

    const messageStatus = await readContract(config, {
      address: destBridgeAddress,
      abi: bridgeABI,
      functionName: 'messageStatus',
      args: [msgHash],
      chainId: connectedChainId,
    });

    log(`Releasing message with status ${messageStatus}`);

    if (messageStatus !== MessageStatus.FAILED) {
      throw new MessageStatusError('message must fail to release funds');
    }
  }

  abstract estimateGas(args: BridgeArgs): Promise<bigint>;
  abstract bridge(args: BridgeArgs): Promise<Hash>;
  abstract claim(args: ClaimArgs): Promise<Hash>;
  abstract release(args: ReleaseArgs): Promise<Hash>;

  // protected async retryClaim(message: Message, bridgeContract: GetContractResult<typeof bridgeABI, WalletClient>) {
  //   log('Retrying message', message);

  //   try {
  //     // Last attempt to send the message: isLastAttempt = true
  //     const txHash = await bridgeContract.write.retryMessage([message, true]);

  //     log('Transaction hash for retryMessage call', txHash);

  //     return txHash;
  //   } catch (err) {
  //     console.error(err);

  //     if (`${err}`.includes('denied transaction signature')) {
  //       throw new UserRejectedRequestError(err as Error);
  //     }

  //     throw new RetryError('failed to retry message', { cause: err });
  //   }
  // }
}
