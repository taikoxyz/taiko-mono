import { writable } from "svelte/store";
import type { Signer } from "ethers";
import { relayerBlockInfoMap } from "../store/relayerApi";
import type { RelayerAPI } from "../domain/relayerApi";
import type { BridgeTransaction, Transactioner } from "../domain/transactions";
import { transactions } from "./transactions";
import { userTokens } from "./userToken";
import type { TokenService } from "src/domain/token";

export const signer = writable<Signer>();

export function subscribeToSigner(relayerApi: RelayerAPI, transactioner: Transactioner, tokenService: TokenService) {
  signer.subscribe(async (store) => {
    if (store) {
      const userAddress = await store.getAddress();

      const apiTxs = await relayerApi.GetAllByAddress(userAddress);

      const blockInfoMap = await relayerApi.GetBlockInfo();
      relayerBlockInfoMap.set(blockInfoMap);

      const txs = await transactioner.GetAllByAddress(userAddress);

      // const hashToApiTxsMap = new Map(apiTxs.map((tx) => {
      //   return [tx.hash, tx];
      // }))

      const updatedStorageTxs: BridgeTransaction[] = txs.filter((tx) => {
        const blockInfo = blockInfoMap.get(tx.fromChainId);
        if (blockInfo?.latestProcessedBlock >= tx.receipt.blockNumber) {
          return false;
        }
        return true;
      });

      transactioner.UpdateStorageByAddress(userAddress, updatedStorageTxs);

      transactions.set([...updatedStorageTxs, ...apiTxs]);

      const tokens = tokenService.GetTokens(userAddress);

      userTokens.set(tokens);
    }

    return store;
  });

  return signer;
}
