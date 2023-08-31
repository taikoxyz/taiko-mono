import { getContract, type Hash } from '@wagmi/core';
import { EventEmitter } from 'events';

import { bridgeABI } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { bridgeTransactionPoller } from '$config';
import { BridgeTxPollingError } from '$libs/error';
import { getLogger } from '$libs/util/logger';
import { nextTick } from '$libs/util/nextTick';

import { isTransactionProcessable } from './isTransactionProcessable';
import { type BridgeTransaction, MessageStatus } from './types';

const log = getLogger('bridge:messageStatusPoller');

export enum PollingEvent {
  STOP = 'stop',
  STATUS = 'status', // emits MessageStatus

  // Whether or not the tx can be clamied/retried/released
  PROCESSABLE = 'processable',
}

type Interval = Maybe<ReturnType<typeof setInterval>>;

// bridgeTx hash => emitter. If there is already a polling ongoing
// we return the emitter associated to it
const hashEmitterMap: Record<Hash, EventEmitter> = {};

// bridgeTx hash => interval. There might be a polling ongoing
// associated to this hash, so we don't want to start another one
const hashIntervalMap: Record<Hash, Interval> = {};

/**
 * @example
 * try {
 *   const { emitter, stopPolling } = startPolling(bridgeTx);
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
export function startPolling(bridgeTx: BridgeTransaction, runImmediately = false) {
  const { hash, srcChainId, destChainId, msgHash, status } = bridgeTx;

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
  let emitter = hashEmitterMap[hash];
  let interval = hashIntervalMap[hash];

  // We are gonna be polling the destination bridge contract
  const destBridgeAddress = routingContractsMap[Number(destChainId)][Number(srcChainId)].bridgeAddress;
  const destBridgeContract = getContract({
    address: destBridgeAddress,
    abi: bridgeABI,
    chainId: Number(destChainId),
  });

  const stopPolling = () => {
    if (interval) {
      log('Stop polling for transaction', bridgeTx);

      // Clean up
      clearInterval(interval);
      delete hashEmitterMap[hash];
      delete hashIntervalMap[hash];

      interval = null;
      emitter.emit(PollingEvent.STOP);
    }
  };

  const destroy = () => {
    stopPolling();
    emitter.removeAllListeners();
  };

  const pollingFn = async () => {
    const isProcessable = await isTransactionProcessable(bridgeTx);

    emitter.emit(PollingEvent.PROCESSABLE, isProcessable);

    try {
      // We want to poll for status changes
      const messageStatus: MessageStatus = await destBridgeContract.read.getMessageStatus([msgHash]);

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

  if (!interval) {
    log('Starting polling for transaction', bridgeTx);

    emitter = new EventEmitter();
    interval = setInterval(pollingFn, bridgeTransactionPoller.interval);

    hashEmitterMap[hash] = emitter;
    hashIntervalMap[hash] = interval;

    // setImmediate isn't standard
    if (runImmediately) {
      // We run the polling function in the next tick so we can
      // attach listeners before the polling function is called
      nextTick(pollingFn);
    }
  } else {
    log('Already polling for transaction', bridgeTx);
  }

  return { destroy, emitter };
}
