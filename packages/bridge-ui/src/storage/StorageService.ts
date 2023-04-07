import type { BridgeTransaction, Transactioner } from '../domain/transactions';
import { BigNumber, Contract, ethers } from 'ethers';
import BridgeABI from '../constants/abi/Bridge';
import TokenVaultABI from '../constants/abi/TokenVault';
import ERC20_ABI from '../constants/abi/ERC20';
import { MessageStatus } from '../domain/message';
import { chains } from '../chain/chains';
import { tokenVaults } from '../vault/tokenVaults';
import type { ChainID } from '../domain/chain';

const STORAGE_PREFIX = 'transactions';

export class StorageService implements Transactioner {
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

  private _getTransactionsFromStorage(address: string): BridgeTransaction[] {
    const transactions = this.storage.getItem(
      `${STORAGE_PREFIX}-${address.toLowerCase()}`,
    );

    let txs: BridgeTransaction[];

    try {
      txs = transactions ? JSON.parse(transactions) : [];
    } catch (e) {
      txs = [];
    }

    return txs;
  }

  async getAllByAddress(address: string): Promise<BridgeTransaction[]> {
    const txs = this._getTransactionsFromStorage(address);

    const bridgeTxs: BridgeTransaction[] = [];

    // TODO: bridgeTxs = (await Promise.all(txs.map(...))).filter(tx => tx) ??
    await Promise.all(
      (txs || [])
        .map(async (tx) => {
          if (tx.from.toLowerCase() !== address.toLowerCase()) return;

          const { toChainId, fromChainId, hash, from } = tx;

          const destProvider = this.providers[toChainId];
          const srcProvider = this.providers[fromChainId];

          // Ignore transactions from chains not supported by the bridge
          if (!srcProvider) return;

          // Returns the transaction receipt for hash or null
          // if the transaction has not been mined.
          const receipt = await srcProvider.getTransactionReceipt(hash);

          if (!receipt) {
            bridgeTxs.push(tx);
            return;
          }

          tx.receipt = receipt; // null => no mined yet

          const destBridgeAddress = chains[toChainId].bridgeAddress;
          const srcBridgeAddress = chains[fromChainId].bridgeAddress;

          const destBridgeContract: Contract = new Contract(
            destBridgeAddress,
            BridgeABI,
            destProvider,
          );

          const srcBridgeContract: Contract = new Contract(
            srcBridgeAddress,
            BridgeABI,
            srcProvider,
          );

          // Gets the event MessageSent from the srcBridgeContract
          // in the block where the transaction was mined.
          const messageSentEventsList = await srcBridgeContract.queryFilter(
            'MessageSent',
            receipt.blockNumber,
            receipt.blockNumber,
          );

          // Find our event MessageSent whose owner is the address passed in
          const messageSentEvent = messageSentEventsList.find(
            (event) =>
              event.args.message.owner.toLowerCase() === address.toLowerCase(),
          );

          if (!messageSentEvent) {
            // No message yet, so we can't get more info from this transaction
            bridgeTxs.push(tx);
            return;
          }

          const { msgHash, message } = messageSentEvent.args;

          const status: number = await destBridgeContract.getMessageStatus(
            msgHash,
          );

          let amountInWei: BigNumber;
          let symbol: string;

          if (message.data !== '0x') {
            // We're dealing with an ERC20 transfer.
            // Let's get the symbol and amount from the TokenVault contract.

            const srcTokenVaultContract = new Contract(
              tokenVaults[fromChainId],
              TokenVaultABI,
              srcProvider,
            );

            const filter = srcTokenVaultContract.filters.ERC20Sent(msgHash);
            const erc20Events = await srcTokenVaultContract.queryFilter(
              filter,
              receipt.blockNumber,
              receipt.blockNumber,
            );

            const erc20Event = erc20Events.find(
              (event) =>
                event.args.msgHash.toLowerCase() === msgHash.toLowerCase(),
            );

            if (!erc20Event) return; // TODO: ???

            const { token, amount } = erc20Event.args;
            const erc20Contract = new Contract(token, ERC20_ABI, srcProvider);

            symbol = await erc20Contract.symbol();
            amountInWei = BigNumber.from(amount);
          }

          const bridgeTx: BridgeTransaction = {
            hash,
            from,
            message,
            receipt,
            msgHash,
            status,
            amountInWei,
            symbol,
            fromChainId,
            toChainId,
          };

          bridgeTxs.push(bridgeTx);
        })

        // TODO: these are not transactions but promises
        //       This filter is doing nothing really. Remove it?
        .filter((tx) => tx),
    );

    // Place new transactions at the top of the list
    bridgeTxs.sort((tx) => (tx.status === MessageStatus.New ? -1 : 1));

    return bridgeTxs;
  }

  // TODO: there is a lot of duplicated code here. Refactor.
  async getTransactionByHash(
    address: string,
    hash: string,
  ): Promise<BridgeTransaction> {
    const txs = this._getTransactionsFromStorage(address);

    const tx: BridgeTransaction = txs.find((tx) => tx.hash === hash);

    if (tx.from.toLowerCase() !== address.toLowerCase()) return;

    const { toChainId, fromChainId, from } = tx;

    const destProvider = this.providers[toChainId];
    const srcProvider = this.providers[fromChainId];

    // Ignore transactions from chains not supported by the bridge
    if (!srcProvider) return;

    // Wait for transaction to be mined...
    await srcProvider.waitForTransaction(tx.hash);

    // ... and then get the receipt.
    const receipt = await srcProvider.getTransactionReceipt(tx.hash);

    if (!receipt) return;

    tx.receipt = receipt;

    const destBridgeAddress = chains[toChainId].bridgeAddress;
    const srcBridgeAddress = chains[fromChainId].bridgeAddress;

    const destBridgeContract: Contract = new Contract(
      destBridgeAddress,
      BridgeABI,
      destProvider,
    );

    const srcBridgeContract: Contract = new Contract(
      srcBridgeAddress,
      BridgeABI,
      srcProvider,
    );

    // Gets the event MessageSent from the srcBridgeContract
    // in the block where the transaction was mined.
    const messageSentEventsList = await srcBridgeContract.queryFilter(
      'MessageSent',
      receipt.blockNumber,
      receipt.blockNumber,
    );

    // Find our event MessageSent whose owner is the address passed in
    const messageSentEvent = messageSentEventsList.find(
      (event) =>
        event.args.message.owner.toLowerCase() === address.toLowerCase(),
    );

    if (!messageSentEvent) return;

    const { msgHash, message } = messageSentEvent.args;

    const status: number = await destBridgeContract.getMessageStatus(msgHash);

    let amountInWei: BigNumber;
    let symbol: string;

    if (message.data !== '0x') {
      // Dealing with an ERC20 transfer. Let's get the symbol
      // and amount from the TokenVault contract.

      const srcTokenVaultContract = new Contract(
        tokenVaults[fromChainId],
        TokenVaultABI,
        srcProvider,
      );

      const filter = srcTokenVaultContract.filters.ERC20Sent(msgHash);
      const erc20Events = await srcTokenVaultContract.queryFilter(
        filter,
        receipt.blockNumber,
        receipt.blockNumber,
      );

      const erc20Event = erc20Events.find(
        (event) => event.args.msgHash.toLowerCase() === msgHash.toLowerCase(),
      );

      if (!erc20Event) return;

      const { token, amount } = erc20Event.args;
      const erc20Contract = new Contract(token, ERC20_ABI, srcProvider);

      symbol = await erc20Contract.symbol();
      amountInWei = BigNumber.from(amount);
    }

    const bridgeTx: BridgeTransaction = {
      hash,
      from,
      message,
      receipt,
      msgHash,
      status,
      amountInWei,
      symbol,
      fromChainId,
      toChainId,
    };

    return bridgeTx;
  }

  updateStorageByAddress(address: string, txs: BridgeTransaction[] = []) {
    this.storage.setItem(
      `${STORAGE_PREFIX}-${address.toLowerCase()}`,
      JSON.stringify(txs),
    );
  }
}
