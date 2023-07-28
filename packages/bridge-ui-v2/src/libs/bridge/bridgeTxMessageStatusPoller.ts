import { getContract } from '@wagmi/core';
import { EventEmitter } from 'events';

import { bridgeABI } from '$abi';
import { bridgeTransactionPoller } from '$config';
import { chainContractsMap } from '$libs/chain';
import { BridgeTxPollingError } from '$libs/error';
import { getLogger } from '$libs/util/logger';
import { nextTick } from '$libs/util/nextTick';

import { isBridgeTxProcessable } from './isBridgeTxProcessable';
import { type BridgeTransaction, MessageStatus } from './types';

const log = getLogger('bridge:bridgeTxMessageStatusPoller');

export enum PollingEvent {
  STOP = 'stop',
  STATUS = 'status', // emits MessageStatus

  // Whether or not the tx can be clamied/retried/released
  PROCESSABLE = 'processable',
}

const intervalEmitterMap: Record<number, EventEmitter> = {};

/**
 * @example:
 * try {
 *   const emitter = startPolling(bridgeTx);
 *
 *   if(emitter) {
 *     emitter.on(PollingEvent.STOP, () => {});
 *     emitter.on(PollingEvent.STATUS, (status: MessageStatus) => {});
 *     emitter.on(PollingEvent.PROCESSABLE, (isProcessable: boolean) => {});
 *   }
 * } catch (err) {
 *   // something really bad with this bridgeTx
 * }
 */
export function startPolling(bridgeTx: BridgeTransaction, runImmediately = true): Maybe<EventEmitter> {
  const { destChainId, msgHash, status } = bridgeTx;

  // Without this we cannot poll at all. Let's throw an error
  // that can be handled in the UI
  if (!msgHash) {
    throw new BridgeTxPollingError('missing msgHash');
  }

  // It could happen that the transaction has already been claimed
  // by the time we want to start polling, in which case we're already done
  if (status === MessageStatus.DONE) return;

  // We want to notify whoever is calling this function of different
  // events: PollingEvent
  const emitter = new EventEmitter();

  const stopPolling = () => {
    if (bridgeTx.interval) {
      log('Stop polling for transaction', bridgeTx);

      clearInterval(bridgeTx.interval);

      bridgeTx.interval = null;

      emitter.emit(PollingEvent.STOP);
    }
  };

  const pollingFn = async () => {
    const isProcessable = await isBridgeTxProcessable(bridgeTx);

    emitter.emit(PollingEvent.PROCESSABLE, isProcessable);

    const destBridgeAddress = chainContractsMap[Number(destChainId)].bridgeAddress;

    const destBridgeContract = getContract({
      address: destBridgeAddress,
      abi: bridgeABI,
      chainId: Number(destChainId),
    });

    try {
      // We want to poll for status changes
      const messageStatus: MessageStatus = await destBridgeContract.read.getMessageStatus([msgHash]);

      bridgeTx.status = messageStatus;

      emitter.emit('status', messageStatus);

      if (messageStatus === MessageStatus.DONE) {
        log('Poller has picked up the change of status to DONE');
        stopPolling();
      }
    } catch (err) {
      console.error(err);

      stopPolling();

      // 😱 UI should handle this error
      throw new BridgeTxPollingError('something bad happened while polling for status', { cause: err });
    }
  };

  if (!bridgeTx.interval) {
    log('Starting polling for transaction', bridgeTx);

    bridgeTx.interval = setInterval(pollingFn, bridgeTransactionPoller.interval);

    intervalEmitterMap[Number(bridgeTx.interval)] = emitter;

    // setImmediate isn't standard
    if (runImmediately) {
      // We run the polling function in the next tick so we can
      // attach listeners before the polling function is called
      nextTick(pollingFn);
    }

    return emitter;
  }

  log('Already polling for transaction', bridgeTx);

  // We are already polling for this transaction.
  // Return the emitter associated to it
  return intervalEmitterMap[Number(bridgeTx.interval)];
}
