<script lang="ts">
  import { setupI18n } from './i18n';
  import { pendingTransactions, transactions } from './store/transaction';
  import Navbar from './components/Navbar.svelte';
  import Toast, { successToast } from './components/Toast.svelte';
  import { signer } from './store/signer';
  import type { BridgeTransaction } from './domain/transaction';

  setupI18n({ withLocale: 'en' });
  import SwitchEthereumChainModal from './components/modals/SwitchEthereumChainModal.svelte';
  import { ethers } from 'ethers';
  import { MessageStatus } from './domain/message';
  import BridgeABI from './constants/abi/Bridge';
  import { relayerBlockInfoMap } from './store/relayerApi';
  import { chains } from './chain/chains';
  import { providers } from './provider/providers';
  import Router from './components/Router.svelte';
  import { relayerApi } from './relayer-api/relayerApi';
  import { storageService, tokenService } from './storage/services';
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
  });

  pendingTransactions.subscribe((store) => {
    (async () => {
      const confirmedPendingTxIndex = await Promise.race(
        store.map((tx, index) => {
          return new Promise<number>((resolve) => {
            $signer.provider
              .waitForTransaction(tx.hash, 1)
              .then(() => resolve(index));
          });
        }),
      );
      successToast('Transaction completed!');
      let s = store;
      s.splice(confirmedPendingTxIndex, 1);
      pendingTransactions.set(s);
    })();
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
