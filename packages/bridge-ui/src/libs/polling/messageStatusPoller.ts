import { getTransactionReceipt } from '@wagmi/core';
import { EventEmitter } from 'events';
import { createPublicClient, getContract, type Hash, type Hex, http, toHex } from 'viem';

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
  let emitter = hashEmitterMap[srcTxHash];
  let interval = hashIntervalMap[srcTxHash];

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
    const interval = hashIntervalMap[srcTxHash];
    if (interval) {
      log('Stop polling for transaction', bridgeTx);

      // Clean up
      clearInterval(interval as ReturnType<typeof setInterval>); // clearInterval only needs the ID
      delete hashEmitterMap[srcTxHash];
      delete hashIntervalMap[srcTxHash];
      hashIntervalMap[srcTxHash] = null;

      emitter.emit(PollingEvent.STOP);
    }
  };

  const destroy = () => {
    stopPolling();
    emitter.removeAllListeners();
  };

  const pollingFn = async () => {
    log('Polling for transaction', bridgeTx.srcTxHash);
    const isProcessable = await isTransactionProcessable(bridgeTx);
    emitter.emit(PollingEvent.PROCESSABLE, isProcessable);

    try {
      const messageStatus: MessageStatus = await destBridgeContract.read.messageStatus([bridgeTx.msgHash]);
      emitter.emit(PollingEvent.STATUS, messageStatus);

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

      let blockNumber: Hex;
      if (!bridgeTx.blockNumber) {
        const receipt = await getTransactionReceipt(config, { hash: bridgeTx.srcTxHash });
        blockNumber = toHex(receipt.blockNumber);
        bridgeTx.blockNumber = blockNumber;
      }

      if (messageStatus === MessageStatus.DONE) {
        log(`Poller has picked up the change of status to DONE for hash ${srcTxHash}.`);
        stopPolling();
      }
    } catch (err) {
      console.error(err);
      stopPolling();
      throw new BridgeTxPollingError('something bad happened while polling for status', { cause: err });
    }
  };

  if (!interval) {
    log('Starting polling for transaction', bridgeTx);

    emitter = new EventEmitter();
    interval = setInterval(pollingFn, bridgeTransactionPoller.interval);

    hashEmitterMap[srcTxHash] = emitter;
    hashIntervalMap[srcTxHash] = interval;

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
