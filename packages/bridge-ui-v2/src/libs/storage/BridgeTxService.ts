import { getContract, waitForTransaction } from '@wagmi/core';
import type { Address, Hash, TransactionReceipt } from 'viem';

import { bridgeABI } from '$abi';
import { pendingTransaction, storageService } from '$config';
import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
import { chainContractsMap, isSupportedChain } from '$libs/chain';
import { jsonParseWithDefault } from '$libs/util/jsonParseWithDefault';
import { getLogger } from '$libs/util/logger';
import { publicClient } from '$libs/wagmi';

const log = getLogger('storage:BridgeTxService');

export class BridgeTxService {
  private readonly storage: Storage;

  private static async _getTransactionReceipt(chainId: number, hash: Hash) {
    const client = publicClient({ chainId });
    return client.getTransactionReceipt({ hash });
  }

  private static async _getBridgeMessageSent(userAddress: Address, chainId: number, blockNumber: number) {
    // Gets the event MessageSent from the bridge contract
    // in the block where the transaction was mined, and find
    // our event MessageSent whose owner is the address passed in

    const bridgeAddress = chainContractsMap[chainId].bridgeAddress;
    const client = publicClient({ chainId });

    const filter = await client.createContractEventFilter({
      abi: bridgeABI,
      address: bridgeAddress,
      eventName: 'MessageSent',
      fromBlock: BigInt(blockNumber),
      toBlock: BigInt(blockNumber),
    });

    const messageSentEvents = await client.getFilterLogs({ filter });

    // Filter out those events that are not from the current address
    return messageSentEvents.find(({ args }) => args.message?.owner.toLowerCase() === userAddress.toLowerCase());
  }

  private static _getBridgeMessageStatus(msgHash: Hash, chainId: number) {
    const bridgeAddress = chainContractsMap[chainId].bridgeAddress;

    const bridgeContract = getContract({
      chainId,
      abi: bridgeABI,
      address: bridgeAddress,
    });

    return bridgeContract.read.getMessageStatus([msgHash]) as Promise<MessageStatus>;
  }

  constructor(storage: Storage) {
    this.storage = storage;
  }

  private _getTxFromStorage(address: Address) {
    const key = `${storageService.bridgeTxPrefix}:${address}`;
    const txs = jsonParseWithDefault(this.storage.getItem(key), []) as BridgeTransaction[];
    return txs;
  }

  private async _enhanceTx(tx: BridgeTransaction, address: Address, waitForTx = false) {
    // Filters out the transactions that are not from the current address
    if (tx.owner.toLowerCase() !== address.toLowerCase()) return;

    const bridgeTx: BridgeTransaction = { ...tx }; // prevent mutation

    const { destChainId, srcChainId, hash } = bridgeTx;

    // Ignore transactions from chains not supported by the bridge
    if (isSupportedChain(srcChainId)) return;

    let receipt: TransactionReceipt | null = null;

    if (waitForTx) {
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

    const messageSentEvent = await BridgeTxService._getBridgeMessageSent(
      address,
      Number(srcChainId),
      Number(receipt.blockNumber),
    );

    if (!messageSentEvent?.args?.msgHash || !messageSentEvent?.args?.message) {
      // No message yet, so we can't get more info from this transaction
      return bridgeTx;
    }

    const { msgHash, message } = messageSentEvent.args;

    // Let's add this new info to the transaction in case something else
    // fails, such as the filter for ERC20Sent events
    bridgeTx.msgHash = msgHash;
    bridgeTx.message = message;

    const status = await BridgeTxService._getBridgeMessageStatus(msgHash, Number(destChainId));

    bridgeTx.status = status;
  }

  async getAllTxByAddress(userAddress: Address) {
    const txs = this._getTxFromStorage(userAddress);

    log('Bridge transactions from storage', txs);

    const enhancedTxPromises = txs.map(async (tx) => this._enhanceTx(tx, userAddress));

    const enhancedTxs = (await Promise.all(enhancedTxPromises))
      // Removes undefined values
      .filter((tx) => Boolean(tx)) as BridgeTransaction[];

    // Place new transactions at the top of the list
    enhancedTxs.sort((tx) => (tx.status === MessageStatus.NEW ? -1 : 1));

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
}
