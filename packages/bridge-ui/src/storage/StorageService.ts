import type { BridgeTransaction, Transactioner } from '../domain/transactions';
import { BigNumber, Contract, ethers } from 'ethers';
import BridgeABI from '../constants/abi/Bridge';
import TokenVaultABI from '../constants/abi/TokenVault';
import { chainIdToTokenVaultAddress } from '../store/bridge';
import { get } from 'svelte/store';
import ERC20 from '../constants/abi/ERC20';
import { MessageStatus } from '../domain/message';
import { chainsRecord } from '../chain/chains';

export class StorageService implements Transactioner {
  private readonly storage: Storage;
  private readonly providerMap: Map<number, ethers.providers.JsonRpcProvider>;

  constructor(
    storage: Storage,
    providerMap: Map<number, ethers.providers.JsonRpcProvider>,
  ) {
    this.storage = storage;
    this.providerMap = providerMap;
  }

  async GetAllByAddress(
    address: string,
    chainID?: number,
  ): Promise<BridgeTransaction[]> {
    const txs: BridgeTransaction[] = JSON.parse(
      this.storage.getItem(`transactions-${address.toLowerCase()}`),
    );

    const bridgeTxs: BridgeTransaction[] = [];

    await Promise.all(
      (txs || [])
        .map(async (tx) => {
          if (tx.from.toLowerCase() !== address.toLowerCase()) return;
          const destChainId = tx.toChainId;
          const destProvider = this.providerMap.get(destChainId);

          const srcProvider = this.providerMap.get(tx.fromChainId);

          // Ignore transactions from chains not supported by the bridge
          if (!srcProvider) {
            return null;
          }

          const receipt = await srcProvider.getTransactionReceipt(tx.hash);

          if (!receipt) {
            bridgeTxs.push(tx);
            return;
          }

          tx.receipt = receipt;

          const destBridgeAddress = chainsRecord[destChainId].bridgeAddress;

          const srcBridgeAddress = chainsRecord[tx.fromChainId].bridgeAddress;

          const destContract: Contract = new Contract(
            destBridgeAddress,
            BridgeABI,
            destProvider,
          );

          const srcContract: Contract = new Contract(
            srcBridgeAddress,
            BridgeABI,
            srcProvider,
          );

          const events = await srcContract.queryFilter(
            'MessageSent',
            receipt.blockNumber,
            receipt.blockNumber,
          );

          const event = events.find(
            (e) => e.args.message.owner.toLowerCase() === address.toLowerCase(),
          );

          if (!event) {
            bridgeTxs.push(tx);
            return;
          }

          const msgHash = event.args.msgHash;

          const messageStatus: number = await destContract.getMessageStatus(
            msgHash,
          );

          let amountInWei: BigNumber;
          let symbol: string;
          if (event.args.message.data !== '0x') {
            const tokenVaultContract = new Contract(
              get(chainIdToTokenVaultAddress).get(tx.fromChainId),
              TokenVaultABI,
              srcProvider,
            );
            const filter = tokenVaultContract.filters.ERC20Sent(msgHash);
            const erc20Events = await tokenVaultContract.queryFilter(
              filter,
              receipt.blockNumber,
              receipt.blockNumber,
            );

            const erc20Event = erc20Events.find(
              (e) => e.args.msgHash.toLowerCase() === msgHash.toLowerCase(),
            );
            if (!erc20Event) return;

            const erc20Contract = new Contract(
              erc20Event.args.token,
              ERC20,
              srcProvider,
            );
            symbol = await erc20Contract.symbol();
            amountInWei = BigNumber.from(erc20Event.args.amount);
          }

          const bridgeTx: BridgeTransaction = {
            hash: tx.hash,
            from: tx.from,
            message: event.args.message,
            receipt: receipt,
            msgHash: event.args.msgHash,
            status: messageStatus,
            amountInWei: amountInWei,
            symbol: symbol,
            fromChainId: tx.fromChainId,
            toChainId: tx.toChainId,
          };

          bridgeTxs.push(bridgeTx);
        })
        .filter((tx) => tx),
    );

    bridgeTxs.sort((tx) => (tx.status === MessageStatus.New ? -1 : 1));

    return bridgeTxs;
  }

  async GetTransactionByHash(
    address: string,
    hash: string,
  ): Promise<BridgeTransaction> {
    const txs: BridgeTransaction[] = JSON.parse(
      this.storage.getItem(`transactions-${address.toLowerCase()}`),
    );

    const tx: BridgeTransaction = txs.find((tx) => tx.hash === hash);

    if (tx.from.toLowerCase() !== address.toLowerCase()) return;
    const destChainId = tx.toChainId;
    const destProvider = this.providerMap.get(destChainId);

    const srcProvider = this.providerMap.get(tx.fromChainId);

    // Ignore transactions from chains not supported by the bridge
    if (!srcProvider) {
      return null;
    }
    await srcProvider.waitForTransaction(tx.hash);
    const receipt = await srcProvider.getTransactionReceipt(tx.hash);

    if (!receipt) {
      return;
    }

    tx.receipt = receipt;

    const destBridgeAddress = chainsRecord[destChainId].bridgeAddress;

    const srcBridgeAddress = chainsRecord[tx.fromChainId].bridgeAddress;

    const destContract: Contract = new Contract(
      destBridgeAddress,
      BridgeABI,
      destProvider,
    );

    const srcContract: Contract = new Contract(
      srcBridgeAddress,
      BridgeABI,
      srcProvider,
    );

    const events = await srcContract.queryFilter(
      'MessageSent',
      receipt.blockNumber,
      receipt.blockNumber,
    );

    const event = events.find(
      (e) => e.args.message.owner.toLowerCase() === address.toLowerCase(),
    );

    if (!event) {
      return;
    }

    const msgHash = event.args.msgHash;

    const messageStatus: number = await destContract.getMessageStatus(msgHash);

    let amountInWei: BigNumber;
    let symbol: string;
    if (event.args.message.data !== '0x') {
      const tokenVaultContract = new Contract(
        get(chainIdToTokenVaultAddress).get(tx.fromChainId),
        TokenVaultABI,
        srcProvider,
      );
      const filter = tokenVaultContract.filters.ERC20Sent(msgHash);
      const erc20Events = await tokenVaultContract.queryFilter(
        filter,
        receipt.blockNumber,
        receipt.blockNumber,
      );

      const erc20Event = erc20Events.find(
        (e) => e.args.msgHash.toLowerCase() === msgHash.toLowerCase(),
      );
      if (!erc20Event) return;

      const erc20Contract = new Contract(
        erc20Event.args.token,
        ERC20,
        srcProvider,
      );
      symbol = await erc20Contract.symbol();
      amountInWei = BigNumber.from(erc20Event.args.amount);
    }

    const bridgeTx: BridgeTransaction = {
      hash: tx.hash,
      from: tx.from,
      message: event.args.message,
      receipt: receipt,
      msgHash: event.args.msgHash,
      status: messageStatus,
      amountInWei: amountInWei,
      symbol: symbol,
      fromChainId: tx.fromChainId,
      toChainId: tx.toChainId,
    };

    return bridgeTx;
  }

  UpdateStorageByAddress(address: string, txs: BridgeTransaction[]) {
    this.storage.setItem(
      `transactions-${address.toLowerCase()}`,
      JSON.stringify(txs),
    );
  }
}
