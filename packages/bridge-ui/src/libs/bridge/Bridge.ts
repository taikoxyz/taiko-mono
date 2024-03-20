import { readContract, simulateContract, writeContract } from '@wagmi/core';
import { getContract, type Hash, UserRejectedRequestError } from 'viem';

import { bridgeAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { MessageStatusError, ProcessMessageError, ReleaseError, WrongChainError, WrongOwnerError } from '$libs/error';
import type { BridgeProver } from '$libs/proof';
import { getConnectedWallet } from '$libs/util/getConnectedWallet';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import {
  type BridgeArgs,
  type ClaimArgs,
  MessageStatus,
  type ProcessMessageType,
  type ReleaseArgs,
  type RetryMessageArgs,
} from './types';

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
  protected async beforeClaiming({ bridgeTx, wallet }: ClaimArgs) {
    const connectedChainId = await wallet.getChainId();
    const { msgHash, message } = bridgeTx;
    if (!message || !msgHash) throw new Error('Message is not defined');

    const destChainId = Number(message.destChainId);
    const srcChainId = Number(message.srcChainId);
    // Are we connected to the destination chain?
    if (connectedChainId !== destChainId) {
      throw new WrongChainError('wallet must be connected to the destination chain');
    }

    const { srcOwner } = message;
    if (!wallet || !wallet.account || !wallet.chain) throw new Error('Wallet is not connected');

    const userAddress = wallet.account.address;
    // Are we the owner of the message?
    if (srcOwner.toLowerCase() !== userAddress.toLowerCase()) {
      throw new WrongOwnerError('user cannot process this as it is not their message');
    }

    const destBridgeAddress = routingContractsMap[connectedChainId][srcChainId].bridgeAddress;

    const messageStatus = await readContract(config, {
      address: destBridgeAddress,
      abi: bridgeAbi,
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
  protected async beforeReleasing({ bridgeTx, wallet }: ClaimArgs) {
    const connectedChainId = await wallet.getChainId();
    const { msgHash, message } = bridgeTx;
    if (!message || !msgHash) throw new Error('Message is not defined');

    const srcChainId = Number(message.srcChainId);
    // Are we connected to the source chain?
    if (connectedChainId !== srcChainId) {
      throw new WrongChainError('wallet must be connected to the source chain');
    }

    const { srcOwner } = message;
    if (!wallet || !wallet.account || !wallet.chain) throw new Error('Wallet is not connected');

    const userAddress = wallet.account.address;
    // Are we the owner of the message?
    if (srcOwner.toLowerCase() !== userAddress.toLowerCase()) {
      throw new WrongOwnerError('user cannot process this as it is not their message');
    }

    // Before releasing we need to make sure the message has failed
    const destChainId = Number(message.destChainId);
    const destBridgeAddress = routingContractsMap[destChainId][srcChainId].bridgeAddress;

    const messageStatus = await readContract(config, {
      address: destBridgeAddress,
      abi: bridgeAbi,
      functionName: 'messageStatus',
      args: [msgHash],
      chainId: connectedChainId,
    });

    log(`Releasing message with status ${messageStatus}`);

    if (messageStatus !== MessageStatus.FAILED) {
      throw new MessageStatusError('message must fail to release funds');
    }
    return;
  }

  abstract estimateGas(args: BridgeArgs): Promise<bigint>;
  abstract bridge(args: BridgeArgs): Promise<Hash>;

  async claim(args: ClaimArgs): Promise<Hash> {
    const { messageStatus, destBridgeAddress } = await this.beforeClaiming(args);
    const { blockNumber } = args.bridgeTx;
    const { message, msgHash } = args.bridgeTx;
    if (!message || !msgHash || !blockNumber)
      throw new ProcessMessageError(
        `message, msgHash or blocknumber is not defined, ${message}, ${msgHash}, ${blockNumber}`,
      );

    const client = await getConnectedWallet();
    if (!client) throw new Error('Client not found');

    const bridgeContract = await getContract({
      client,
      abi: bridgeAbi,
      address: destBridgeAddress,
    });

    try {
      let txHash: Hash;
      if (messageStatus === MessageStatus.NEW) {
        txHash = await this.processNewMessage({ ...args, bridgeContract, client });
      } else if (messageStatus === MessageStatus.RETRIABLE) {
        txHash = await this.retryMessage({ ...args, bridgeContract, client });
      } else if (messageStatus === MessageStatus.FAILED) {
        txHash = await this.release({ ...args, bridgeContract, client });
      } else {
        throw new ProcessMessageError('Message status not supported for claiming.');
      }
      return txHash;
    } catch (err) {
      if (`${err}`.includes('denied transaction signature')) {
        console.error(err);
        throw new UserRejectedRequestError(err as Error);
      }
      throw err;
    }
  }

  private async processNewMessage(args: ProcessMessageType): Promise<Hash> {
    const { bridgeTx, bridgeContract, client } = args;
    const { message } = bridgeTx;
    if (!message) throw new ProcessMessageError('Message is not defined');
    const proof = await this._prover.getEncodedSignalProof({ bridgeTx });
    const estimatedGas = await bridgeContract.estimateGas.processMessage([message, proof], { account: client.account });
    log('Estimated gas for processMessage', estimatedGas);

    const { request } = await simulateContract(config, {
      address: bridgeContract.address,
      abi: bridgeContract.abi,
      functionName: 'processMessage',
      args: [message, proof],
      gas: estimatedGas,
    });
    log('Simulate contract for processMessage', request);

    return await writeContract(config, request);
  }

  private async retryMessage(args: RetryMessageArgs): Promise<Hash> {
    const { bridgeTx, bridgeContract, client } = args;
    const isFinalAttempt = args.lastAttempt || false;
    const { message } = bridgeTx;

    isFinalAttempt ? log('Retrying message for the last time') : log('Retrying message');

    if (!message) throw new ProcessMessageError('Message is not defined');

    const estimatedGas = await bridgeContract.estimateGas.retryMessage([message, isFinalAttempt], {
      account: client.account,
    });

    log('Estimated gas for retryMessage', estimatedGas);

    const { request } = await simulateContract(config, {
      address: bridgeContract.address,
      abi: bridgeContract.abi,
      functionName: 'retryMessage',
      args: [message, isFinalAttempt],
      gas: estimatedGas,
    });
    log('Simulate contract for retryMessage', request);

    return await writeContract(config, request);
  }

  private async release(args: ReleaseArgs) {
    await this.beforeReleasing(args);

    const { bridgeTx, bridgeContract, client } = args;
    const { message } = bridgeTx;
    if (!message) throw new ReleaseError('Message is not defined');
    const proof = await this._prover.getEncodedSignalProof({ bridgeTx });
    const estimatedGas = await bridgeContract.estimateGas.recallMessage([message, proof], { account: client.account });
    log('Estimated gas for processMessage', estimatedGas);

    const { request } = await simulateContract(config, {
      address: bridgeContract.address,
      abi: bridgeContract.abi,
      functionName: 'recallMessage',
      args: [message, proof],
      gas: estimatedGas,
    });
    log('Simulate contract for processMessage', request);

    return await writeContract(config, request);
    //   let txHash: Hash;
    //   const { message, msgHash } = args.bridgeTx;
    //   if (!message || !msgHash) throw new ReleaseError('Message is not defined');

    //   if (messageStatus === MessageStatus.FAILED) {
    //     const proof = await this._prover.getEncodedSignalProof({ bridgeTx: args.bridgeTx });
    //     try {
    //       const { request } = await simulateContract(config, {
    //         address: destBridgeAddress,
    //         abi: bridgeAbi,
    //         functionName: 'recallMessage',
    //         args: [message, proof],
    //         gas: message.gasLimit,
    //       });
    //       log('Simulate contract', request);

    //       txHash = await writeContract(config, request);
    //       log('Transaction hash for recallMessage call', txHash);
    //       return txHash;
    //     } catch (err) {
    //       console.error(err);
    //       if (`${err}`.includes('denied transaction signature')) {
    //         throw new UserRejectedRequestError(err as Error);
    //       }
    //       throw new ReleaseError('failed to release ETH', { cause: err });
    //     }
    //   }
    //   throw new ReleaseError('Message status not supported for release');
    // }
  }
}
