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

    // Removes the confirmed transaction from the pendingTransactions store
    const copyPendingTransactions = newPendingTxs.slice(); // prevents mutation
    copyPendingTransactions.splice(confirmedPendingTxIndex, 1);

    pendingTransactions.set(copyPendingTransactions);
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
