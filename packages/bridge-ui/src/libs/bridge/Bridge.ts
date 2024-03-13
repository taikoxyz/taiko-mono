import { readContract, simulateContract, writeContract } from '@wagmi/core';
import { getContract, type Hash, UserRejectedRequestError } from 'viem';

import { bridgeAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { MessageStatusError, ProcessMessageError, ReleaseError, WrongChainError, WrongOwnerError } from '$libs/error';
import type { BridgeProver } from '$libs/proof';
import { getConnectedWallet } from '$libs/util/getConnectedWallet';
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
    return { messageStatus, destBridgeAddress };
  }

  abstract estimateGas(args: BridgeArgs): Promise<bigint>;
  abstract bridge(args: BridgeArgs): Promise<Hash>;

  async claim(args: ClaimArgs) {
    const { messageStatus, destBridgeAddress } = await this.beforeClaiming(args);

    let txHash: Hash;
    const { message, msgHash } = args.bridgeTx;
    if (!message || !msgHash) throw new ProcessMessageError('Message is not defined');

    if (messageStatus === MessageStatus.NEW) {
      const proof = await this._prover.getEncodedSignalProof({ bridgeTx: args.bridgeTx });
      try {
        const client = await getConnectedWallet();
        if (!client) throw new Error('Client not found');

        const bridgeContract = await getContract({
          client,
          abi: bridgeAbi,
          address: destBridgeAddress,
        });

        const estimatedGas = await bridgeContract.estimateGas.processMessage([message, proof], {
          account: client.account,
        });
        log('Estimated gas', estimatedGas);

        const { request } = await simulateContract(config, {
          address: destBridgeAddress,
          abi: bridgeAbi,
          functionName: 'processMessage',
          args: [message, proof],
          gas: estimatedGas,
        });
        log('Simulate contract', request);

        txHash = await writeContract(config, request);
        log('Transaction hash for processMessage call', txHash);
        return txHash;
      } catch (err) {
        console.error(err);
        if (`${err}`.includes('denied transaction signature')) {
          throw new UserRejectedRequestError(err as Error);
        }
        throw new ProcessMessageError('failed to claim ETH', { cause: err });
      }
    } else if (messageStatus === MessageStatus.RETRIABLE) {
      try {
        const client = await getConnectedWallet();
        if (!client) throw new Error('Client not found');

        const bridgeContract = await getContract({
          client,
          abi: bridgeAbi,
          address: destBridgeAddress,
        });

        const estimatedGas = await bridgeContract.estimateGas.retryMessage([message, false], {
          account: client.account,
        });
        log('Estimated gas', estimatedGas);

        const { request } = await simulateContract(config, {
          address: destBridgeAddress,
          abi: bridgeAbi,
          functionName: 'retryMessage',
          args: [message, false],
          gas: estimatedGas,
        });
        log('Simulate contract', request);

        txHash = await writeContract(config, request);
        log('Transaction hash for retry call', txHash);
        return txHash;
      } catch (err) {
        console.error(err);
        if (`${err}`.includes('denied transaction signature')) {
          throw new UserRejectedRequestError(err as Error);
        }
        throw new ProcessMessageError('failed to claim ETH again', { cause: err });
      }
    }
    throw new ProcessMessageError('Message status not supported for claiming.');
  }

  async release(args: ReleaseArgs) {
    const { messageStatus, destBridgeAddress } = await this.beforeReleasing(args);

    let txHash: Hash;
    const { message, msgHash } = args.bridgeTx;
    if (!message || !msgHash) throw new ReleaseError('Message is not defined');

    if (messageStatus === MessageStatus.FAILED) {
      const proof = await this._prover.getEncodedSignalProof({ bridgeTx: args.bridgeTx });
      try {
        const { request } = await simulateContract(config, {
          address: destBridgeAddress,
          abi: bridgeAbi,
          functionName: 'recallMessage',
          args: [message, proof],
          gas: message.gasLimit,
        });
        log('Simulate contract', request);

        txHash = await writeContract(config, {
          address: destBridgeAddress,
          abi: bridgeAbi,
          functionName: 'recallMessage',
          args: [message, proof],
          gas: message.gasLimit,
        });
        log('Transaction hash for recallMessage call', txHash);
        return txHash;
      } catch (err) {
        console.error(err);
        if (`${err}`.includes('denied transaction signature')) {
          throw new UserRejectedRequestError(err as Error);
        }
        throw new ReleaseError('failed to release ETH', { cause: err });
      }
    }
    throw new ReleaseError('Message status not supported for release');
  }
}
