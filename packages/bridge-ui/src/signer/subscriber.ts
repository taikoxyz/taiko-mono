import type { Signer } from 'ethers';
import { relayerBlockInfoMap } from '../store/relayerApi';
import { relayerApi } from '../relayer-api/relayerApi';
import { storageService, tokenService } from '../storage/services';
import type { BridgeTransaction } from '../domain/transaction';
import { transactions } from '../store/transaction';
import { userTokens } from '../store/token';

/**
 * Subscribe to signer changes.
 * When there is a new signer, we need to get the address and
 * merge API transactions with local stored transactions for that address.
 */
export async function subscribeToSigner(newSigner: Signer | null) {
  if (newSigner) {
    const userAddress = await newSigner.getAddress();

    // Get transactions from API
    const apiTxs = await relayerApi.getAllBridgeTransactionByAddress(
      userAddress,
    );

    // TODO: this will be used in the future
    const blockInfoMap = await relayerApi.getBlockInfo();
    relayerBlockInfoMap.set(blockInfoMap);

    // Get transactions from local storage
    const txs = await storageService.getAllByAddress(userAddress);

    // Create a map of hashes to API transactions to help us
    // filter out transactions from local storage.
    const hashToApiTxsMap = new Map(
      apiTxs.map((tx) => {
        return [tx.hash.toLowerCase(), 1];
      }),
    );

    // Filter out transactions that are already in the API
    const updatedStorageTxs: BridgeTransaction[] = txs.filter((tx) => {
      return !hashToApiTxsMap.has(tx.hash.toLowerCase());
    });

    // const updatedStorageTxs: BridgeTransaction[] = txs.filter((tx) => {
    //   const blockInfo = blockInfoMap.get(tx.fromChainId);
    //   if (blockInfo?.latestProcessedBlock >= tx.receipt?.blockNumber) {
    //     return false;
    //   }
    //   return true;
    // });

    storageService.updateStorageByAddress(userAddress, updatedStorageTxs);

    // Merge transactions from API and local storage
    transactions.set([...updatedStorageTxs, ...apiTxs]);

    // Get tokens based on current user address (signer)
    const tokens = tokenService.getTokens(userAddress);
    userTokens.set(tokens);
  }
}
