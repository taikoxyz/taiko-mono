import { getTransactionReceipt } from '@wagmi/core';
import { EventEmitter } from 'events';
import { createPublicClient, getContract, type Hash, http, toHex } from 'viem';

import { bridgeAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { bridgeTransactionPoller } from '$config';
import { chains } from '$libs/chain';
import { BridgeTxPollingError } from '$libs/error';
import { getLogger } from '$libs/util/logger';
import { nextTick } from '$libs/util/nextTick';
import { config } from '$libs/wagmi';

import { isTransactionProcessable } from '../bridge/isTransactionProcessable';
import { type BridgeTransaction, MessageStatus } from '../bridge/types';

const log = getLogger('bridge:messageStatusPoller');

export enum PollingEvent {
  STOP = 'stop',
  STATUS = 'status', // emits MessageStatus

  // Whether or not the tx can be clamied/retried/released, or null where that could not be read
  PROCESSABLE = 'processable',
}

type Interval = Maybe<ReturnType<typeof setInterval>>;

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type PollingHandlers = Partial<Record<PollingEvent, (...args: any[]) => void>>;

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
 *     emitter.on(PollingEvent.STOP, onStop);
 *     emitter.on(PollingEvent.STATUS, onStatus);
 *     emitter.on(PollingEvent.PROCESSABLE, onProcessable);
 *   }
 *   // on teardown, pass back exactly the handlers that were added:
 *   // destroy({ [PollingEvent.STATUS]: onStatus, [PollingEvent.PROCESSABLE]: onProcessable })
 * } catch (err) {
 *   // something really bad with this bridgeTx
 * }
 */
export function startPolling(bridgeTx: BridgeTransaction, runImmediately = true) {
  const { srcTxHash, srcChainId, destChainId, msgHash, msgStatus } = bridgeTx;

  // Without this we cannot poll at all. Let's throw an error
  // that can be handled in the UI
  if (!msgHash) {
    throw new BridgeTxPollingError('missing msgHash');
  }

  // It could happen that the transaction has already been claimed
  // by the time we want to start polling, in which case we're already done
  if (msgStatus === MessageStatus.DONE) return;

  // We want to notify whoever is calling this function of different
  // events: PollingEvent
  // Keyed by message, not by transaction: a transaction that emitted two messages would
  // otherwise share one emitter and one interval, so the second message was never polled
  // and its subscribers were fed the first message's status
  let emitter = hashEmitterMap[msgHash];
  let interval = hashIntervalMap[msgHash];

  const destChainClient = createPublicClient({
    chain: chains.find((chain) => chain.id === Number(destChainId)),
    transport: http(),
  });

  const srcChainClient = createPublicClient({
    chain: chains.find((chain) => chain.id === Number(srcChainId)),
    transport: http(),
  });

  // We are gonna be polling the destination bridge contract
  const destBridgeAddress = routingContractsMap[Number(destChainId)][Number(srcChainId)].bridgeAddress;
  const destBridgeContract = getContract({
    address: destBridgeAddress,
    abi: bridgeAbi,
    client: destChainClient,
  });

  // In case for recalled messages we need to check the source bridge contract
  const srcBridgeAddress = routingContractsMap[Number(srcChainId)][Number(destChainId)].bridgeAddress;
  const srcBridgeContract = getContract({
    address: srcBridgeAddress,
    abi: bridgeAbi,
    client: srcChainClient,
  });

  const stopPolling = () => {
    const interval = hashIntervalMap[msgHash];
    if (interval) {
      log('Stop polling for transaction', bridgeTx);

      // Clean up
      clearInterval(interval as ReturnType<typeof setInterval>); // clearInterval only needs the ID
      delete hashEmitterMap[msgHash];
      delete hashIntervalMap[msgHash];

      emitter.emit(PollingEvent.STOP);
    }
  };

  // `handlers` is required: the emitter is shared by every subscriber of the same
  // transaction hash, so a subscriber may only ever remove the handlers it added.
  // A no-arg teardown would silently stop polling for all other rows.
  const destroy = (handlers: PollingHandlers) => {
    // The parameter stays required so TypeScript still rejects a no-arg teardown, but the
    // read is guarded: an untyped caller getting a TypeError here would take down the
    // whole row, and removing nothing is the safe answer for a shared emitter anyway
    for (const [event, handler] of Object.entries(handlers ?? {})) {
      if (handler) emitter.removeListener(event, handler);
    }

    const hasListeners = Object.values(PollingEvent).some((event) => emitter.listenerCount(event) > 0);
    if (!hasListeners) stopPolling();
  };

  const pollingFn = async () => {
    log('Polling for transaction', bridgeTx.srcTxHash);

    try {
      const isProcessable = await isTransactionProcessable(bridgeTx);
      emitter.emit(PollingEvent.PROCESSABLE, isProcessable);
    } catch (err) {
      // Kept separate from the status read below: one failing must not skip the other,
      // and neither may escape into setInterval where nothing can catch it
      console.error('Error while checking whether the transaction is processable, will retry', err);
    }

    try {
      const messageStatus: MessageStatus = await destBridgeContract.read.messageStatus([bridgeTx.msgHash]);
      emitter.emit(PollingEvent.STATUS, messageStatus);

      // Terminal, so nothing below can change the answer - and nothing below may be allowed
      // to prevent it being acted on. This used to sit after the receipt read, so a source
      // RPC that could not serve the receipt threw past it into the catch: every tick then
      // re-read DONE, re-emitted it, retried the receipt and never stopped, for a message
      // that was already finalised. The block number is only needed by the proof paths, and
      // a processed message has none left.
      if (messageStatus === MessageStatus.DONE) {
        log(`Poller has picked up the change of status to DONE for hash ${srcTxHash}.`);
        stopPolling();
        return;
      }

      if (messageStatus === MessageStatus.FAILED) {
        // check if the message is recalled
        const recallStatus = await srcBridgeContract.read.messageStatus([bridgeTx.msgHash]);
        if (recallStatus === MessageStatus.RECALLED) {
          log(`Message ${bridgeTx.msgHash} has been recalled.`);
          emitter.emit(PollingEvent.STATUS, MessageStatus.RECALLED);
          stopPolling();
          return;
        }
      }

      if (!bridgeTx.blockNumber) {
        // The bridge tx lives on the source chain; the wallet may be connected elsewhere.
        // Isolated the way the processable read above is: this only fills in a block number
        // for the proof paths, so failing to read it must not skip the rest of the tick.
        try {
          const receipt = await getTransactionReceipt(config, {
            hash: bridgeTx.srcTxHash,
            chainId: Number(srcChainId),
          });
          bridgeTx.blockNumber = toHex(receipt.blockNumber);
        } catch (err) {
          console.error('Error while reading the source transaction receipt, will retry', err);
        }
      }
    } catch (err) {
      // A transient RPC failure must not permanently end polling for this transaction;
      // the next interval tick simply tries again
      console.error('Error while polling for message status, will retry', err);
    }
  };

  if (!interval) {
    log('Starting polling for transaction', bridgeTx);

    emitter = new EventEmitter();
    interval = setInterval(pollingFn, bridgeTransactionPoller.interval);

    hashEmitterMap[msgHash] = emitter;
    hashIntervalMap[msgHash] = interval;

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
