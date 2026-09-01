import { getPublicClient, waitForTransactionReceipt } from '@wagmi/core';
import { type Address, type Hash, numberToHex, type TransactionReceipt } from 'viem';

import { bridgeAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { pendingTransaction, storageService } from '$config';
import { isSameBridgeTx } from '$libs/bridge/bridgeTxIdentity';
import { getMessageStatusForMsgHash } from '$libs/bridge/getMessageStatusForMsgHash';
import { type BridgeTransaction, type Message, MessageStatus } from '$libs/bridge/types';
import { isSupportedChain } from '$libs/chain';
import { FilterLogsError } from '$libs/error';
import { jsonParseWithDefault } from '$libs/util/jsonParseWithDefault';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

const log = getLogger('storage:BridgeTxService');

export class BridgeTxService {
  private readonly storage: Storage;

  //Todo: duplicate code in RelayerAPIService
  private static async _getTransactionReceipt(chainId: number, hash: Hash) {
    try {
      return await waitForTransactionReceipt(config, {
        hash,
        chainId: Number(chainId),
        timeout: pendingTransaction.waitTimeout,
      });
    } catch (error) {
      log(`Error getting transaction receipt for ${hash}: ${error}`);
      return null;
    }
  }

  private static async _getBridgeMessageSent({
    userAddress,
    srcChainId,
    destChainId,
    blockNumber,
  }: {
    userAddress: Address;
    srcChainId: number;
    destChainId: number;
    blockNumber: number;
  }) {
    // Gets the event MessageSent from the bridge contract
    // in the block where the transaction was mined, and find
    // our event MessageSent whose owner is the address passed in

    const bridgeAddress = routingContractsMap[srcChainId][destChainId].bridgeAddress;
    const client = await getPublicClient(config, { chainId: srcChainId });

    if (!client) throw new Error('Could not get public client');

    try {
      // eth_getLogs, not eth_newFilter: creating a filter is a stateful RPC method, and a
      // load-balanced gateway cannot serve it ("stateful method requires a single targeted
      // upstream"). Retrying only recreated the same filter, so it failed identically.
      // The range is a single block, so a direct log query is exactly equivalent.
      const messageSentEvents = await client.getContractEvents({
        abi: bridgeAbi,
        address: bridgeAddress,
        eventName: 'MessageSent',
        fromBlock: BigInt(blockNumber),
        toBlock: BigInt(blockNumber),
      });

      // Filter out those events that are not from the current address
      return messageSentEvents.find(({ args }) => args.message?.srcOwner.toLowerCase() === userAddress.toLowerCase());
    } catch (error) {
      console.error('Error getting MessageSent logs', error);
      throw new FilterLogsError('Error getting logs via filter');
    }
  }

  constructor(storage: Storage) {
    this.storage = storage;
  }

  /**
   * @dev Restores the bigint fields JSON cannot carry.
   *
   *      addTxByAddress stringifies every bigint on the way in, and JSON.parse has no
   *      reviver on the way out, so a stored transaction comes back with strings where the
   *      type promises bigints. That is not cosmetic: shouldShowManualClaimEntry compares
   *      `processingFee === 0n`, which a string can never satisfy, so the manual claim
   *      entry never appeared for exactly the zero-fee transactions it exists for. The
   *      other three survive only because their consumers happen to be string-tolerant.
   *
   * @param tx A transaction as it came out of storage
   * @return tx_ The same transaction with its numeric fields typed as declared
   */
  private static _restoreBigInts(tx: BridgeTransaction): BridgeTransaction {
    return {
      ...tx,
      amount: BigInt(tx.amount ?? 0),
      processingFee: BigInt(tx.processingFee ?? 0),
      srcChainId: BigInt(tx.srcChainId ?? 0),
      destChainId: BigInt(tx.destChainId ?? 0),
      ...(tx.fee === undefined || tx.fee === null ? {} : { fee: BigInt(tx.fee) }),
      ...(tx.message ? { message: BridgeTxService._restoreMessageBigInts(tx.message) } : {}),
    };
  }

  /**
   * @dev Restores the bigints inside a stored message.
   *
   *      Nothing writes a message to storage today - ConfirmationStep records a
   *      transaction without one, and the message _enhanceTx reads off the receipt is
   *      returned rather than written back - so this is a guard rather than a fix for a
   *      reachable path. It is here because the failure it prevents is silent: a message
   *      whose id, value and fee came back as strings is handed straight to proof
   *      generation and to the recall path, which encode them as uint256.
   *
   * @param message A message as it came out of storage
   * @return message_ The same message with its numeric fields typed as declared
   */
  private static _restoreMessageBigInts(message: Message): Message {
    return {
      ...message,
      id: BigInt(message.id ?? 0),
      srcChainId: BigInt(message.srcChainId ?? 0),
      destChainId: BigInt(message.destChainId ?? 0),
      value: BigInt(message.value ?? 0),
      fee: BigInt(message.fee ?? 0),
      gasLimit: Number(message.gasLimit ?? 0),
    };
  }

  private _getTxFromStorage(address: Address) {
    const key = `${storageService.bridgeTxPrefix}-${address}`;
    const txs = jsonParseWithDefault(this.storage.getItem(key), []) as BridgeTransaction[];
    return txs.map(BridgeTxService._restoreBigInts);
  }

  private async _enhanceTx(tx: BridgeTransaction, address: Address, waitForTx: boolean) {
    // Filters out the transactions that are not from the current address
    // if (tx.from.toLowerCase() !== address.toLowerCase()) return;

    const bridgeTx: BridgeTransaction = { ...tx }; // prevent mutation

    const { destChainId, srcChainId, srcTxHash } = bridgeTx;

    // Ignore transactions from chains not supported by the bridge
    if (!isSupportedChain(Number(srcChainId))) return;

    let receipt: TransactionReceipt | null = null;

    if (waitForTx) {
      // We might want to wait for the transaction to be mined
      try {
        receipt = await BridgeTxService._getTransactionReceipt(Number(srcChainId), srcTxHash);
      } catch (error) {
        console.error('Error waiting for transaction receipt', error);
      }
    }

    if (!receipt) {
      return bridgeTx;
    }

    // We have receipt
    bridgeTx.receipt = receipt;

    // Populate blockNumber from receipt if not already set
    if (!bridgeTx.blockNumber) {
      bridgeTx.blockNumber = numberToHex(receipt.blockNumber);
    }

    let messageSentEvent;

    try {
      messageSentEvent = await BridgeTxService._getBridgeMessageSent({
        userAddress: address,
        srcChainId: Number(srcChainId),
        destChainId: Number(destChainId),
        blockNumber: Number(receipt.blockNumber),
      });
    } catch (error) {
      //TODO: handle error
      console.error('Error getting bridge message sent', error);

      return bridgeTx;
    }

    if (!messageSentEvent?.args?.msgHash || !messageSentEvent?.args?.message) {
      // No message yet, so we can't get more info from this transaction
      return bridgeTx;
    }

    const { msgHash, message } = messageSentEvent.args;

    // Let's add this new info to the transaction in case something else
    // fails, such as the filter for ERC20Sent events
    bridgeTx.msgHash = msgHash;
    bridgeTx.message = message;

    const status = await getMessageStatusForMsgHash({
      msgHash: msgHash,
      srcChainId: Number(srcChainId),
      destChainId: Number(destChainId),
    });

    bridgeTx.msgStatus = status;
    return bridgeTx;
  }

  async getAllTxByAddress(address: Address) {
    const txs = this._getTxFromStorage(address);

    log('Bridge transactions from storage', txs);

    // Helper to wrap enhancement with timeout - returns original tx if enhancement times out
    const enhanceWithTimeout = async (tx: BridgeTransaction, timeoutMs = 10000) => {
      const timeoutPromise = new Promise<BridgeTransaction>((resolve) => {
        setTimeout(() => {
          log('Enhancement timed out for tx, returning unenhanced', tx.srcTxHash);
          resolve(tx); // Return original tx if timeout
        }, timeoutMs);
      });
      try {
        const result = await Promise.race([this._enhanceTx(tx, address, true), timeoutPromise]);
        return result ?? tx; // Return original tx if _enhanceTx returns undefined
      } catch (error) {
        log('Enhancement failed for tx, returning unenhanced', tx.srcTxHash, error);
        return tx; // Return original tx on error
      }
    };

    const enhancedTxPromises = txs.map((tx) => enhanceWithTimeout(tx));

    // Use allSettled so one failing tx doesn't block others
    const settledResults = await Promise.allSettled(enhancedTxPromises);

    // Extract fulfilled values, falling back to original tx for rejected ones
    const resolvedTxs = settledResults.map((result, idx) => {
      if (result.status === 'fulfilled') {
        return result.value;
      }
      log('Enhancement rejected for tx', txs[idx].srcTxHash, result.reason);
      return txs[idx]; // Return original tx
    });

    // Remove any undefined values from the array of resolved transactions
    const enhancedTxs = resolvedTxs.filter((tx): tx is BridgeTransaction => Boolean(tx));

    // Place new transactions at the top of the list
    enhancedTxs.sort((tx1, tx2) => {
      if (tx1.msgStatus === MessageStatus.NEW && tx2.msgStatus !== MessageStatus.NEW) {
        return -1; // tx1 is newer
      }

      if (tx1.msgStatus !== MessageStatus.NEW && tx2.msgStatus === MessageStatus.NEW) {
        return 1; // tx2 is newer
      }

      if (tx1.msgStatus === MessageStatus.NEW && tx2.msgStatus === MessageStatus.NEW) {
        // If both are new, sort by timestamp
        return tx2.timestamp && tx1.timestamp ? tx2.timestamp - tx1.timestamp : 0;
      }

      return 0;
    });

    log('Enhanced transactions', [...enhancedTxs]);

    return enhancedTxs;
  }

  async getTxByHash(hash: Hash, address: Address) {
    const txs = this._getTxFromStorage(address);

    const tx = txs.find((tx) => tx.srcTxHash === hash) as BridgeTransaction;

    log('Transaction from storage', { ...tx });

    const enhancedTx = await this._enhanceTx(tx, address, true);

    log('Enhanced transaction', enhancedTx);

    return enhancedTx;
  }

  /**
   * @dev Writes the list, serializing bigints as strings.
   *
   *      Both write paths go through here. updateByAddress used to call JSON.stringify
   *      bare, which throws on a bigint - it only worked because everything read back out
   *      of storage was a string. Now that reads restore the declared types, a bare
   *      stringify would fail on the removal path.
   */
  private _setTxsInStorage(address: Address, txs: BridgeTransaction[]) {
    const key = `${storageService.bridgeTxPrefix}-${address}`;
    this.storage.setItem(
      key,
      JSON.stringify(txs, (_, value) => (typeof value === 'bigint' ? value.toString() : value)),
    );
  }

  addTxByAddress(address: Address, tx: BridgeTransaction) {
    const txs = this._getTxFromStorage(address);

    txs.unshift(tx);

    log('Adding transaction to storage', tx);

    this._setTxsInStorage(address, txs);
  }

  updateByAddress(address: Address, txs: BridgeTransaction[]) {
    log('Updating storage with transactions', txs);
    this._setTxsInStorage(address, txs);
  }

  removeTransactions(address: Address, txs: BridgeTransaction[]) {
    log('Removing transactions from storage', txs);
    const txsFromStorage = this._getTxFromStorage(address);

    const filteredTxs = txsFromStorage.filter((tx) => !txs.some((toRemove) => isSameBridgeTx(tx, toRemove)));

    this.updateByAddress(address, filteredTxs);
  }

  clearStorageByAddress(address: Address) {
    log('Clearing storage for address', address);
    const key = `${storageService.bridgeTxPrefix}-${address}`;
    this.storage.removeItem(key);
  }

  transactionIsStoredLocally(address: Address, tx: BridgeTransaction) {
    const txs = this._getTxFromStorage(address);
    return txs.some((t) => isSameBridgeTx(t, tx));
  }
}
