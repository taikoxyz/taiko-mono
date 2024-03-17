import { EventEmitter } from 'events';
import { createPublicClient, getContract, type Hash, http } from 'viem';

import { bridgeAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { bridgeTransactionPoller } from '$config';
import { getInvocationDelayForTx } from '$libs/bridge/getInvocationDelayForTx';
import { getProofReceiptForMsgHash } from '$libs/bridge/getProofReceiptForMsgHash';
import { chains } from '$libs/chain';
import { BridgeTxPollingError, NoDelaysForBridgeError } from '$libs/error';
import { getLogger } from '$libs/util/logger';
import { nextTick } from '$libs/util/nextTick';

import { isTransactionProcessable } from '../bridge/isTransactionProcessable';
import { type BridgeTransaction, type GetProofReceiptResponse, MessageStatus } from '../bridge/types';

const log = getLogger('bridge:messageStatusPoller');

export enum PollingEvent {
  STOP = 'stop',
  STATUS = 'status', // emits MessageStatus
  DELAY = 'remainingDelayInSeconds', // emits remaining claim delay in seconds

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

// Keep track of the last delay we fetched for a transaction, so we can stop polling if it's 0
const hashDelayMap: Record<Hash, bigint> = {};

// bridgeTx hash => proof receipt. We want to keep track of the proof receipt
const hashProofReceiptMap: Record<Hash, GetProofReceiptResponse> = {};

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
  const { hash, srcChainId, destChainId, msgHash, msgStatus } = bridgeTx;

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
  let emitter = hashEmitterMap[hash];
  let interval = hashIntervalMap[hash];

  const destChainClient = createPublicClient({
    chain: chains.find((chain) => chain.id === Number(destChainId)),
    transport: http(),
  });

  // We are gonna be polling the destination bridge contract
  const destBridgeAddress = routingContractsMap[Number(destChainId)][Number(srcChainId)].bridgeAddress;
  const destBridgeContract = getContract({
    address: destBridgeAddress,
    abi: bridgeAbi,
    client: destChainClient,
  });

  const stopPolling = () => {
    const interval = hashIntervalMap[hash];
    if (interval) {
      log('Stop polling for transaction', bridgeTx);

      // Clean up
      clearInterval(interval as ReturnType<typeof setInterval>); // clearInterval only needs the ID
      delete hashEmitterMap[hash];
      delete hashIntervalMap[hash];
      hashIntervalMap[hash] = null;

      emitter.emit(PollingEvent.STOP);
    }
  };

  const destroy = () => {
    stopPolling();
    emitter.removeAllListeners();
  };

  const pollingFn = async () => {
    log('Polling for transaction', bridgeTx.hash);
    const isProcessable = await isTransactionProcessable(bridgeTx);
    emitter.emit(PollingEvent.PROCESSABLE, isProcessable);

    try {
      const messageStatus: MessageStatus = await destBridgeContract.read.messageStatus([bridgeTx.msgHash]);
      emitter.emit(PollingEvent.STATUS, messageStatus);

      // 1. check if we already have a proof receipt for this message hash
      // 2. if not, fetch it and store it
      // 3. if the stored proof receipt is not 0, get the delays and store them
      // 4. emit the remaining delay
      // 5. if the delay is 0, stop polling

      let proofReceipts = null;
      if (hashProofReceiptMap[hash] === undefined || hashProofReceiptMap[hash] === null) {
        proofReceipts = await getProofReceiptForMsgHash({
          msgHash,
          destChainId,
          srcChainId,
        });
      }
      if (proofReceipts && proofReceipts.length > 0 && proofReceipts[0] !== 0n) {
        hashProofReceiptMap[hash] = proofReceipts;
        log('Proof receipt found for message hash, checking delays', msgHash);
        if (hashDelayMap[hash] > 0n || hashDelayMap[hash] === null || hashDelayMap[hash] === undefined) {
          try {
            const txDelays = await getInvocationDelayForTx(bridgeTx);
            const remainingDelayInSeconds = txDelays.preferredDelay;
            log('Remaining delay in seconds', remainingDelayInSeconds);
            hashDelayMap[hash] = remainingDelayInSeconds;
            emitter.emit(PollingEvent.DELAY, remainingDelayInSeconds);

            if (remainingDelayInSeconds === 0n) {
              log(`Delay for hash ${hash} is 0, will not fetch again.`);
            }
          } catch (err) {
            if (err instanceof NoDelaysForBridgeError) {
              log('Destination chain does not have delays, not fetching again.');
              hashDelayMap[hash] = 0n;
            } else {
              throw err;
            }
          }
        }
      } else if (hashDelayMap[hash] <= 0n) {
        log(`Delay for hash ${hash} is already 0 or negative. Skipping.`);
      }

      if (messageStatus === MessageStatus.DONE) {
        log(`Poller has picked up the change of status to DONE for hash ${hash}.`);
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
