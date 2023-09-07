import { getContract, waitForTransaction } from '@wagmi/core';
import type { Address, Hash, TransactionReceipt } from 'viem';

import { bridgeABI } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { pendingTransaction, storageService } from '$config';
import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
import { isSupportedChain } from '$libs/chain';
import { jsonParseWithDefault } from '$libs/util/jsonParseWithDefault';
import { getLogger } from '$libs/util/logger';
import { publicClient } from '$libs/wagmi';

const log = getLogger('storage:BridgeTxService');

type BridgeMessageParams = {
  msgHash: Hash;
  srcChainId: number;
  destChainId: number;
};

export class BridgeTxService {
  private readonly storage: Storage;

  //Todo: duplicate code in RelayerAPIService
  private static async _getTransactionReceipt(chainId: number, hash: Hash) {
    log(`Getting transaction receipt for ${hash} on chain ${chainId}`);
    try {
      const client = publicClient({ chainId });
      const receipt = await client.getTransactionReceipt({ hash });
      return receipt;
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
    const client = publicClient({ chainId: srcChainId });

    const filter = await client.createContractEventFilter({
      abi: bridgeABI,
      address: bridgeAddress,
      eventName: 'MessageSent',
      fromBlock: BigInt(blockNumber),
      toBlock: BigInt(blockNumber),
    });

    // todo: this seems to fail sometimes, work out why and add error handling
    const messageSentEvents = await client.getFilterLogs({ filter });

    // Filter out those events that are not from the current address
    return messageSentEvents.find(({ args }) => args.message?.user.toLowerCase() === userAddress.toLowerCase());
  }

  private static _getBridgeMessageStatus({ msgHash, srcChainId, destChainId }: BridgeMessageParams) {
    // Gets the status of the message from the destination bridge contract
    const bridgeAddress = routingContractsMap[destChainId][srcChainId].bridgeAddress;

    const bridgeContract = getContract({
      chainId: destChainId,
      abi: bridgeABI,
      address: bridgeAddress,
    });

    return bridgeContract.read.getMessageStatus([msgHash]) as Promise<MessageStatus>;
  }

  constructor(storage: Storage) {
    this.storage = storage;
  }

  private _getTxFromStorage(address: Address) {
    const key = `${storageService.bridgeTxPrefix}-${address}`;
    const txs = jsonParseWithDefault(this.storage.getItem(key), []) as BridgeTransaction[];
    return txs;
  }

  private async _enhanceTx(tx: BridgeTransaction, address: Address, waitForTx = false) {
    // Filters out the transactions that are not from the current address
    if (tx.from.toLowerCase() !== address.toLowerCase()) return;

    const bridgeTx: BridgeTransaction = { ...tx }; // prevent mutation

    const { destChainId, srcChainId, hash } = bridgeTx;

    // Ignore transactions from chains not supported by the bridge
    if (!isSupportedChain(Number(srcChainId))) return;

    let receipt: TransactionReceipt | null = null;

    if (waitForTx) {
      // We might want to wait for the transaction to be mined
      receipt = await waitForTransaction({
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

    const messageSentEvent = await BridgeTxService._getBridgeMessageSent({
      userAddress: address,
      srcChainId: Number(srcChainId),
      destChainId: Number(destChainId),
      blockNumber: Number(receipt.blockNumber),
    });

    if (!messageSentEvent?.args?.msgHash || !messageSentEvent?.args?.message) {
      // No message yet, so we can't get more info from this transaction
      return bridgeTx;
    }

    const { msgHash, message } = messageSentEvent.args;

    // Let's add this new info to the transaction in case something else
    // fails, such as the filter for ERC20Sent events
    bridgeTx.msgHash = msgHash;
    bridgeTx.message = message;

    const status = await BridgeTxService._getBridgeMessageStatus({
      msgHash: msgHash,
      srcChainId: Number(srcChainId),
      destChainId: Number(destChainId),
    });

    bridgeTx.status = status;
    return bridgeTx;
  }

  async getAllTxByAddress(address: Address) {
    const txs = this._getTxFromStorage(address);

    log('Bridge transactions from storage', txs);

    const enhancedTxPromises = txs.map((tx) => this._enhanceTx(tx, address));

    const resolvedTxs = await Promise.all(enhancedTxPromises);

    // Remove any undefined values from the array of resolved transactions
    const enhancedTxs = resolvedTxs.filter((tx): tx is BridgeTransaction => Boolean(tx));

    // Place new transactions at the top of the list
    enhancedTxs.sort((tx1, tx2) => {
      if (tx1.status === MessageStatus.NEW && tx2.status !== MessageStatus.NEW) {
        return -1; // tx1 is newer
      }

      if (tx1.status !== MessageStatus.NEW && tx2.status === MessageStatus.NEW) {
        return 1; // tx2 is newer
      }

      if (tx1.status === MessageStatus.NEW && tx2.status === MessageStatus.NEW) {
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
