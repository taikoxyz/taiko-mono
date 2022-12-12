import type { BridgeTransaction, Transactioner } from "../domain/transactions";
import { Contract, ethers } from "ethers";
import Bridge from "../constants/abi/Bridge";
import { chains, CHAIN_MAINNET, CHAIN_TKO } from "../domain/chain";

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
    const txs: ethers.Transaction[] = JSON.parse(
      this.storage.getItem("transactions")
    );

    const bridgeTxs: BridgeTransaction[] = [];

    await Promise.all(
      (txs || []).map(async (tx) => {
        const destChainId =
          tx.chainId === CHAIN_MAINNET.id ? CHAIN_TKO.id : CHAIN_MAINNET.id;
        const destProvider = this.providerMap.get(destChainId);

        const srcProvider = this.providerMap.get(tx.chainId);

        const receipt = await srcProvider.getTransactionReceipt(tx.hash);

        if (!receipt) return;

        const destBridgeAddress = chains[destChainId].bridgeAddress;

        const srcBridgeAddress = chains[tx.chainId].bridgeAddress;

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

        if (!event) return;

        const signal = event.args.signal;

        const messageStatus: number = await destContract.getMessageStatus(
          signal
        );

        const bridgeTx: BridgeTransaction = {
          message: event.args.message,
          receipt: receipt,
          signal: event.args.signal,
          ethersTx: tx,
          status: messageStatus,
        };

        console.log(bridgeTx);

        bridgeTxs.push(bridgeTx);
      })
    );

    return bridgeTxs;
  }
}

export { StorageService };
