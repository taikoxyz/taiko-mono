import type { BridgeTransaction, Transactioner } from "../domain/transactions";
import { Contract, ethers } from "ethers";
import Bridge from "../constants/abi/Bridge";
import { chains } from "../domain/chain";

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
        const provider = this.providerMap.get(tx.chainId);

        const receipt = await provider.getTransactionReceipt(tx.hash);

        const destBridgeAddress = chains[tx.chainId].bridgeAddress;

        const contract: Contract = new Contract(
          destBridgeAddress,
          Bridge,
          provider
        );

        let events = await contract.queryFilter(
          "MessageSent",
          receipt.blockNumber,
          receipt.blockNumber
        );

        const event = events.find(
          (e) => e.args.message.owner.toLowerCase() === address.toLowerCase()
        );

        if (!event) return;

        const signal = event.args.signal;

        const messageStatus: number = await contract.getMessageStatus(signal);

        console.log(event.args.message);
        const bridgeTx: BridgeTransaction = {
          message: event.args.message,
          receipt: receipt,
          signal: event.args.signal,
          ethersTx: tx,
          status: messageStatus,
        };

        bridgeTxs.push(bridgeTx);
      })
    );

    return bridgeTxs;
  }
}

export { StorageService };
