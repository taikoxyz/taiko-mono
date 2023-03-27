<script lang="ts">
  import { pendingTransactions, transactions } from './store/transaction';
  import Navbar from './components/Navbar.svelte';
  import Toast, { successToast } from './components/Toast.svelte';
  import { signer } from './store/signer';

  import SwitchEthereumChainModal from './components/modals/SwitchEthereumChainModal.svelte';
  import { ethers } from 'ethers';
  import { MessageStatus } from './domain/message';
  import BridgeABI from './constants/abi/Bridge';
  import { chains } from './chain/chains';
  import { providers } from './provider/providers';
  import Router from './components/Router.svelte';
  import { relayerApi } from './relayer-api/relayerApi';
  import { storageService, tokenService } from './storage/services';
  import type { BridgeTransaction } from './domain/transaction';
  import { userTokens } from './store/token';

  /**
   * Subscribe to signer changes.
   * When there is a new signer, we need to get the address and
   * merge API transactions with local stored transactions for that address.
   */
  signer.subscribe(async (newSigner) => {
    if (newSigner) {
      const userAddress = await newSigner.getAddress();

      // Get transactions from API
      const apiTxs = await relayerApi.GetAllBridgeTransactionByAddress(
        userAddress,
      );

      // Get transactions from local storage
      const localTxs = await storageService.GetAllByAddress(userAddress);

      // Create a map of hashes to API transactions to help us
      // filter out transactions from local storage.
      const hashToApiTxsMap = new Map(
        apiTxs.map((tx) => {
          return [tx.hash.toLowerCase(), 1];
        }),
      );

      // Filter out transactions that are already in the API
      const updatedStorageTxs: BridgeTransaction[] = localTxs.filter((tx) => {
        return !hashToApiTxsMap.has(tx.hash.toLowerCase());
      });

      storageService.UpdateStorageByAddress(userAddress, updatedStorageTxs);

      // Merge transactions from API and local storage
      transactions.set([...updatedStorageTxs, ...apiTxs]);

      // Get tokens based on current user address (signer)
      const tokens = tokenService.GetTokens(userAddress);
      userTokens.set(tokens);
    }
  });

  /**
   * Subscribe to pendingTransactions changes.
   */
  pendingTransactions.subscribe(async (newPendingTxs) => {
    const promiseIndexes = newPendingTxs.map(async (tx, index) => {
      // Returns a Promise which will not resolve until transactionHash is mined
      await $signer.provider.waitForTransaction(tx.hash, 1);
      return index;
    });

    // Gets the index of the first transaction that's mined
    const confirmedPendingTxIndex = await Promise.race(promiseIndexes);

    successToast('Transaction completed!');

    const s = newPendingTxs.slice(confirmedPendingTxIndex, 0);
    pendingTransactions.set(s);
  });

  const transactionToIntervalMap = new Map();

  transactions.subscribe((store) => {
    if (store) {
      store.forEach((tx) => {
        const txInterval = transactionToIntervalMap.get(tx.hash);
        if (txInterval) {
          clearInterval(txInterval);
          transactionToIntervalMap.delete(tx.hash);
        }

        if (tx.status === MessageStatus.New) {
          const provider = providers[tx.toChainId];

          const interval = setInterval(async () => {
            const txInterval = transactionToIntervalMap.get(tx.hash);
            if (txInterval !== interval) {
              clearInterval(txInterval);
              transactionToIntervalMap.delete(tx.hash);
            }

            transactionToIntervalMap.set(tx.hash, interval);
            if (!tx.msgHash) return;

            const contract = new ethers.Contract(
              chains[tx.toChainId].bridgeAddress,
              BridgeABI,
              provider,
            );

            const messageStatus: MessageStatus =
              await contract.getMessageStatus(tx.msgHash);

            if (messageStatus === MessageStatus.Done) {
              successToast('Bridge message processed successfully');
              const txOngoingInterval = transactionToIntervalMap.get(tx.hash);
              clearInterval(txOngoingInterval);
              transactionToIntervalMap.delete(tx.hash);
            }
          }, 20 * 1000);
        }
      });
    }
  });
</script>

<main>
  <Navbar />
  <Router />
</main>

<Toast />

<SwitchEthereumChainModal />

<style>
  main {
    font-family: 'Inter', sans-serif;
  }
</style>
