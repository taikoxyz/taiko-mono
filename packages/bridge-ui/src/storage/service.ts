import type { BridgeTransaction, Transactioner } from "../domain/transactions";
import { BigNumber, Contract, ethers } from "ethers";
import Bridge from "../constants/abi/Bridge";
import { chains, CHAIN_MAINNET, CHAIN_TKO } from "../domain/chain";
import TokenVault from "../constants/abi/TokenVault";
import { chainIdToTokenVaultAddress } from "../store/bridge";
import { get } from "svelte/store";
import ERC20 from "../constants/abi/ERC20";
import { MessageStatus } from "../domain/message";

interface storage {
  getItem(key: string): string;
}

class StorageService implements Transactioner {
  private readonly storage: storage;
  private readonly providerMap: Map<number, ethers.providers.JsonRpcProvider>;

  constructor(
    storage: storage,
    providerMap: Map<number, ethers.providers.JsonRpcProvider>
  ) {
    this.storage = storage;
    this.providerMap = providerMap;
  }

  async GetAllByAddress(
    address: string,
    chainID?: number
  ): Promise<BridgeTransaction[]> {
    const txs: BridgeTransaction[] = JSON.parse(
      this.storage.getItem(`transactions-${address.toLowerCase()}`)
    );

    const bridgeTxs: BridgeTransaction[] = [];

    await Promise.all(
      (txs || []).map(async (tx) => {
        if (tx.ethersTx.from.toLowerCase() !== address.toLowerCase()) return;
        const destChainId = tx.toChainId;
        const destProvider = this.providerMap.get(destChainId);

        const srcProvider = this.providerMap.get(tx.fromChainId);

        const receipt = await srcProvider.getTransactionReceipt(
          tx.ethersTx.hash
        );

        if (!receipt) {
          bridgeTxs.push(tx);
          return;
        }

        tx.receipt = receipt;

        const destBridgeAddress = chains[destChainId].bridgeAddress;

        const srcBridgeAddress = chains[tx.fromChainId].bridgeAddress;

        const destContract: Contract = new Contract(
          destBridgeAddress,
          Bridge,
          destProvider
        );

        const srcContract: Contract = new Contract(
          srcBridgeAddress,
          Bridge,
          srcProvider
        );

        const events = await srcContract.queryFilter(
          "MessageSent",
          receipt.blockNumber,
          receipt.blockNumber
        );

        const event = events.find(
          (e) => e.args.message.owner.toLowerCase() === address.toLowerCase()
        );

        if (!event) {
          bridgeTxs.push(tx);
          return;
        }

        const signal = event.args.signal;

        const messageStatus: number = await destContract.getMessageStatus(
          signal
        );

        let amountInWei: BigNumber;
        let symbol: string;
        if (event.args.message.data !== "0x") {
          const tokenVaultContract = new Contract(
            get(chainIdToTokenVaultAddress).get(tx.fromChainId),
            TokenVault,
            srcProvider
          );
          const erc20Events = await tokenVaultContract.queryFilter(
            "ERC20Sent",
            receipt.blockNumber,
            receipt.blockNumber
          );

          const erc20Event = erc20Events.find(
            (e) => e.args.signal.toLowerCase() === signal.toLowerCase()
          );

          if (!erc20Event) return;

          const erc20Contract = new Contract(
            erc20Event.args.token,
            ERC20,
            srcProvider
          );
          symbol = await erc20Contract.symbol();
          amountInWei = BigNumber.from(erc20Event.args.amount);
        }

        const bridgeTx: BridgeTransaction = {
          message: event.args.message,
          receipt: receipt,
          signal: event.args.signal,
          ethersTx: tx.ethersTx,
          status: messageStatus,
          amountInWei: amountInWei,
          symbol: symbol,
          fromChainId: tx.fromChainId,
          toChainId: tx.toChainId,
        };

        bridgeTxs.push(bridgeTx);
      })
    );

    bridgeTxs.sort((tx) => (tx.status === MessageStatus.New ? -1 : 1));

    return bridgeTxs;
  }
}

export { StorageService };
