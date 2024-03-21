import { getPublicClient, waitForTransactionReceipt } from '@wagmi/core';
import type { Address, Hash, TransactionReceipt } from 'viem';

import { bridgeAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { pendingTransaction, storageService } from '$config';
import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
import { getMessageStatusForMsgHash } from '$libs/bridge/getMessageStatusForMsgHash';
import { isSupportedChain } from '$libs/chain';
import { FilterLogsError } from '$libs/error';
import { fetchTransactionReceipt } from '$libs/util/fetchTransactionReceipt';
import { jsonParseWithDefault } from '$libs/util/jsonParseWithDefault';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

const log = getLogger('storage:BridgeTxService');

export class BridgeTxService {
  private readonly storage: Storage;

  //Todo: duplicate code in RelayerAPIService
  private static async _getTransactionReceipt(chainId: number, hash: Hash) {
    try {
      return await fetchTransactionReceipt(hash, chainId);
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

    const filter = await client.createContractEventFilter({
      abi: bridgeAbi,
      address: bridgeAddress,
      eventName: 'MessageSent',
      fromBlock: BigInt(blockNumber),
      toBlock: BigInt(blockNumber),
    });

    try {
      const messageSentEvents = await client.getFilterLogs({ filter });
      // Filter out those events that are not from the current address
      return messageSentEvents.find(({ args }) => args.message?.srcOwner.toLowerCase() === userAddress.toLowerCase());
    } catch (error) {
      log('Error getting logs via filter, retrying...', error);

      // we try again, often recreating the filter fixes the issue
      try {
        const filter = await client.createContractEventFilter({
          abi: bridgeAbi,
          address: bridgeAddress,
          eventName: 'MessageSent',
          fromBlock: BigInt(blockNumber),
          toBlock: BigInt(blockNumber),
        });
        const messageSentEvents = await client.getFilterLogs({ filter });
        // Filter out those events that are not from the current address
        return messageSentEvents.find(({ args }) => args.message?.srcOwner.toLowerCase() === userAddress.toLowerCase());
      } catch (error) {
        console.error('Error filtering logs', error);
        throw new FilterLogsError('Error getting logs via filter');
      }
    }
  }

  constructor(storage: Storage) {
    this.storage = storage;
  }

  private _getTxFromStorage(address: Address) {
    const key = `${storageService.bridgeTxPrefix}-${address}`;
    const txs = jsonParseWithDefault(this.storage.getItem(key), []) as BridgeTransaction[];
    return txs;
  }

  private async _enhanceTx(tx: BridgeTransaction, address: Address, waitForTx: boolean) {
    // Filters out the transactions that are not from the current address
    if (tx.from.toLowerCase() !== address.toLowerCase()) return;

    const bridgeTx: BridgeTransaction = { ...tx }; // prevent mutation

    const { destChainId, srcChainId, hash } = bridgeTx;

    // Ignore transactions from chains not supported by the bridge
    if (!isSupportedChain(Number(srcChainId))) return;

    let receipt: TransactionReceipt | null = null;

    if (waitForTx) {
      // We might want to wait for the transaction to be mined
      receipt = await waitForTransactionReceipt(config, {
        hash,
        chainId: Number(srcChainId),
        timeout: pendingTransaction.waitTimeout,
      });
    } else {
      // Returns the transaction receipt for hash or null
      // if the transaction has not been mined.
      receipt = await BridgeTxService._getTransactionReceipt(Number(srcChainId), hash);
    }

    if (!receipt) {
      return bridgeTx;
    }

    // We have receipt
    bridgeTx.receipt = receipt;

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

    const enhancedTxPromises = txs.map((tx) => this._enhanceTx(tx, address, true));

    const resolvedTxs = await Promise.all(enhancedTxPromises);

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

    const tx = txs.find((tx) => tx.hash === hash) as BridgeTransaction;

    log('Transaction from storage', { ...tx });

    const enhancedTx = await this._enhanceTx(tx, address, true);

    log('Enhanced transaction', enhancedTx);

    return enhancedTx;
  }

  addTxByAddress(address: Address, tx: BridgeTransaction) {
    const txs = this._getTxFromStorage(address);

    txs.unshift(tx);

    log('Adding transaction to storage', tx);

    const key = `${storageService.bridgeTxPrefix}-${address}`;
    this.storage.setItem(
      key,
      // We need to serialize the BigInts as strings
      JSON.stringify(txs, (_, value) => (typeof value === 'bigint' ? value.toString() : value)),
    );
  }

  updateByAddress(address: Address, txs: BridgeTransaction[]) {
    log('Updating storage with transactions', txs);
    const key = `${storageService.bridgeTxPrefix}-${address}`;
    this.storage.setItem(key, JSON.stringify(txs));
  }

  removeTransactions(address: Address, txs: BridgeTransaction[]) {
    log('Removing transactions from storage', txs);
    const txsFromStorage = this._getTxFromStorage(address);

    const txsToRemove = txs.map((tx) => tx.hash);

    const filteredTxs = txsFromStorage.filter((tx) => !txsToRemove.includes(tx.hash));

    this.updateByAddress(address, filteredTxs);
  }

  clearStorageByAddress(address: Address) {
    log('Clearing storage for address', address);
    const key = `${storageService.bridgeTxPrefix}-${address}`;
    this.storage.removeItem(key);
  }
}
