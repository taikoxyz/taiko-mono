import { BigNumber, Contract, ethers } from 'ethers';
import type { Address } from 'wagmi';

import { chains } from '../chain/chains';
import { bridgeABI, erc20ABI, tokenVaultABI } from '../constants/abi';
import type { ChainID } from '../domain/chain';
import { MessageStatus } from '../domain/message';
import type { BridgeTransaction, Transactioner } from '../domain/transaction';
import { isETHByMessage } from '../utils/isETHByMessage';
import { jsonParseOrEmptyArray } from '../utils/jsonParseOrEmptyArray';
import { getLogger } from '../utils/logger';
import { tokenVaults } from '../vault/tokenVaults';

const log = getLogger('StorageService');

const STORAGE_PREFIX = 'transactions';

export class StorageService implements Transactioner {
  private static async _getBridgeMessageSent(
    userAddress: Address,
    bridgeAddress: Address,
    bridgeAbi: ethers.ContractInterface,
    provider: ethers.providers.StaticJsonRpcProvider,
    blockNumber: number,
  ) {
    const bridgeContract: Contract = new Contract(
      bridgeAddress,
      bridgeAbi,
      provider,
    );

    // Gets the event MessageSent from the bridge contract
    // in the block where the transaction was mined, and find
    // our event MessageSent whose owner is the address passed in
    const messageSentEvents = await bridgeContract.queryFilter(
      'MessageSent',
      blockNumber,
      blockNumber,
    );

    return messageSentEvents.find(
      ({ args }) =>
        args.message.owner.toLowerCase() === userAddress.toLowerCase(),
    );
  }

  private static _getBridgeMessageStatus(
    bridgeAddress: Address,
    bridgeAbi: ethers.ContractInterface,
    provider: ethers.providers.StaticJsonRpcProvider,
    msgHash: string,
  ) {
    const bridgeContract: Contract = new Contract(
      bridgeAddress,
      bridgeAbi,
      provider,
    );

    return bridgeContract.getMessageStatus(msgHash);
  }

  private static async _getTokenVaultERC20Event(
    tokenVaultAddress: Address,
    tokenVaultAbi: ethers.ContractInterface,
    provider: ethers.providers.StaticJsonRpcProvider,
    msgHash: string,
    blockNumber: number,
  ) {
    const tokenVaultContract = new Contract(
      tokenVaultAddress,
      tokenVaultAbi,
      provider,
    );

    const filter = tokenVaultContract.filters.ERC20Sent(msgHash);

    const events = await tokenVaultContract.queryFilter(
      filter,
      blockNumber,
      blockNumber,
    );

    return events.find(
      ({ args }) => args.msgHash.toLowerCase() === msgHash.toLowerCase(),
    );
  }

  private static async _getERC20Details(
    erc20Event: ethers.Event,
    erc20Abi: ethers.ContractInterface,
    provider: ethers.providers.StaticJsonRpcProvider,
  ): Promise<[BigNumber, string, number]> {
    const { token, amount } = erc20Event.args;
    const erc20Contract = new Contract(token, erc20Abi, provider);

    const symbol: string = await erc20Contract.symbol();
    const decimals: number = await erc20Contract.decimals();
    const bnAmount: BigNumber = BigNumber.from(amount);

    return [bnAmount, symbol, decimals];
  }

  private readonly storage: Storage;
  private readonly providers: Record<
    ChainID,
    ethers.providers.StaticJsonRpcProvider
  >;

  constructor(
    storage: Storage,
    providers: Record<ChainID, ethers.providers.StaticJsonRpcProvider>,
  ) {
    this.storage = storage;
    this.providers = providers;
  }

  private _getTransactionsFromStorage(address: Address): BridgeTransaction[] {
    const existingTransactions = this.storage.getItem(
      `${STORAGE_PREFIX}-${address.toLowerCase()}`,
    );

    return jsonParseOrEmptyArray<BridgeTransaction>(existingTransactions);
  }

  async getAllByAddress(address: Address): Promise<BridgeTransaction[]> {
    const txs = this._getTransactionsFromStorage(address);

    log('Transactions from storage', txs);
    log('Getting details for each transaction from blockchain…');

    const txsPromises = txs.map(async (tx) => {
      if (tx.from.toLowerCase() !== address.toLowerCase()) return;

      const bridgeTx: BridgeTransaction = { ...tx }; // prevents mutation of tx

      const { destChainId, srcChainId, hash } = bridgeTx;

      const destProvider = this.providers[destChainId];
      const srcProvider = this.providers[srcChainId];

      // Ignore transactions from chains not supported by the bridge
      if (!srcProvider) return;

      // Returns the transaction receipt for hash or null
      // if the transaction has not been mined.
      const receipt = await srcProvider.getTransactionReceipt(hash);

      if (!receipt) {
        return bridgeTx;
      }

      bridgeTx.receipt = receipt;

      // TODO: should we dependency-inject the chains?
      const srcBridgeAddress = chains[srcChainId].bridgeAddress;

      const messageSentEvent = await StorageService._getBridgeMessageSent(
        address,
        srcBridgeAddress,
        bridgeABI,
        srcProvider,
        receipt.blockNumber,
      );

      if (!messageSentEvent) {
        // No message yet, so we can't get more info from this transaction
        return bridgeTx;
      }

      const { msgHash, message } = messageSentEvent.args;

      // Let's add this new info to the transaction in case something else
      // fails, such as the filter for ERC20Sent events
      bridgeTx.msgHash = msgHash;
      bridgeTx.message = message;

      const destBridgeAddress = chains[destChainId].bridgeAddress;

      const status = await StorageService._getBridgeMessageStatus(
        destBridgeAddress,
        bridgeABI,
        destProvider,
        msgHash,
      );

      bridgeTx.status = status;

      let amount: BigNumber;
      let symbol: string;
      let decimals: number;

      if (!isETHByMessage(message)) {
        // We're dealing with an ERC20 transfer.
        // Let's get the symbol and amount from the TokenVault contract.

        const srcTokenVaultAddress = tokenVaults[srcChainId];

        const erc20Event = await StorageService._getTokenVaultERC20Event(
          srcTokenVaultAddress,
          tokenVaultABI,
          srcProvider,
          msgHash,
          receipt.blockNumber,
        );

        if (!erc20Event) {
          return bridgeTx;
        }

        [amount, symbol, decimals] = await StorageService._getERC20Details(
          erc20Event,
          erc20ABI,
          srcProvider,
        );
      }

      bridgeTx.amount = amount;
      bridgeTx.symbol = symbol;
      bridgeTx.decimals = decimals;

      return bridgeTx;
    });

    const bridgeTxs: BridgeTransaction[] = (
      await Promise.all(txsPromises)
    ).filter((tx) => Boolean(tx)); // Removes undefined values

    // Place new transactions at the top of the list
    bridgeTxs.sort((tx) => (tx.status === MessageStatus.New ? -1 : 1));

    // Spreading to preserve original txs in case of array mutation
    log('Enhanced transactions', [...bridgeTxs]);

    return bridgeTxs;
  }

  async getTransactionByHash(
    address: Address,
    hash: string,
  ): Promise<BridgeTransaction | undefined> {
    const txs = this._getTransactionsFromStorage(address);

    const tx: BridgeTransaction = txs.find((tx) => tx.hash === hash);

    // Spreading to preserve original tx
    log('Transaction from storage', { ...tx });

    if (!tx || tx.from.toLowerCase() !== address.toLowerCase()) return;

    const { destChainId, srcChainId } = tx;

    const destProvider = this.providers[destChainId];
    const srcProvider = this.providers[srcChainId];

    // Ignore transactions from chains not supported by the bridge
    if (!srcProvider) return;

    // Wait for transaction to be mined...
    await srcProvider.waitForTransaction(tx.hash);

    // ... and then get the receipt.
    const receipt = await srcProvider.getTransactionReceipt(tx.hash);

    if (!receipt) return tx;

    tx.receipt = receipt;

    // TODO: should we dependency-inject the chains?
    const srcBridgeAddress = chains[srcChainId].bridgeAddress;

    const messageSentEvent = await StorageService._getBridgeMessageSent(
      address,
      srcBridgeAddress,
      bridgeABI,
      srcProvider,
      receipt.blockNumber,
    );

    if (!messageSentEvent) return tx;

    const { msgHash, message } = messageSentEvent.args;

    tx.msgHash = msgHash;
    tx.message = message;

    const destBridgeAddress = chains[destChainId].bridgeAddress;

    const status = await StorageService._getBridgeMessageStatus(
      destBridgeAddress,
      bridgeABI,
      destProvider,
      msgHash,
    );

    tx.status = status;

    let amount: BigNumber;
    let symbol: string;
    let decimals: number;

    if (!isETHByMessage(message)) {
      // Dealing with an ERC20 transfer. Let's get the symbol
      // and amount from the TokenVault contract.

      const srcTokenVaultAddress = tokenVaults[srcChainId];

      const erc20Event = await StorageService._getTokenVaultERC20Event(
        srcTokenVaultAddress,
        tokenVaultABI,
        srcProvider,
        msgHash,
        receipt.blockNumber,
      );

      if (!erc20Event) {
        return tx;
      }

      [amount, symbol, decimals] = await StorageService._getERC20Details(
        erc20Event,
        erc20ABI,
        srcProvider,
      );
    }

    const bridgeTx = {
      ...tx,
      amount,
      symbol,
      decimals,
    } as BridgeTransaction;

    log('Enhanced transaction', bridgeTx);

    return bridgeTx;
  }

  updateStorageByAddress(address: Address, txs: BridgeTransaction[] = []) {
    log('Updating storage with transactions', txs);
    this.storage.setItem(
      `${STORAGE_PREFIX}-${address.toLowerCase()}`,
      JSON.stringify(txs),
    );
  }
}
