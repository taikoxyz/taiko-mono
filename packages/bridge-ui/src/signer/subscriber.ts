import type { Signer } from 'ethers';
import { storageService, tokenService } from '../storage/services';
import { transactions } from '../store/transactions';
import { userTokens } from '../store/userToken';
import type { BridgeTransaction } from '../domain/transactions';
import { relayerApi } from '../relayer-api/relayerApi';
import { paginationInfo, relayerBlockInfoMap } from '../store/relayerApi';
import { getLogger } from '../utils/logger';

const log = getLogger('signer:subscriber');

/**
 * Subscribe to signer changes.
 * When there is a new signer, we need to get the address and
 * merge API transactions with the ones in localStorage for that address.
 * Get also tokens from localStorage.
 */
export async function subscribeToSigner(newSigner: Signer | null) {
  if (newSigner) {
    log('New signer set', newSigner);

    // TODO: we actually don't want to run all this if the address
    //       is the same as the previous one.
    const userAddress = await newSigner.getAddress();

    const { txs: apiTxs, paginationInfo: pageInto } =
      await relayerApi.getAllBridgeTransactionByAddress(userAddress, {
        page: 0,
        size: 100, // 100 transactions max
      });

    const blockInfoMap = await relayerApi.getBlockInfo();
    relayerBlockInfoMap.set(blockInfoMap);

    const txs = await storageService.getAllByAddress(userAddress);

    // Create a map of hashes to API transactions to help us
    // filter out transactions from local storage.
    const hashToApiTxsMap = new Map(
      apiTxs.map((tx) => {
        return [tx.hash.toLowerCase(), true];
      }),
    );

    // Filter out transactions that are already in the txs from relayer API
    const updatedStorageTxs: BridgeTransaction[] = txs.filter((tx) => {
      return !hashToApiTxsMap.has(tx.hash.toLowerCase());
    });

    storageService.updateStorageByAddress(userAddress, updatedStorageTxs);

    // Merge transactions from API and local storage
    transactions.set([...updatedStorageTxs, ...apiTxs]);

    // Get tokens based on current user address (signer)
    const tokens = tokenService.getTokens(userAddress);
    userTokens.set(tokens);

    // This store is also used to indicate we have transactions ready
    // to be displayed in the UI.
    paginationInfo.set(pageInto);
  } else {
    log('Signer deleted');
    transactions.set([]);
    userTokens.set([]);
    paginationInfo.set(null);
  }
}
