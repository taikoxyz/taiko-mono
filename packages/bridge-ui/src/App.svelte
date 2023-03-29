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

  // TODO: hmmm, nope. This is dangerous and hard to follow.
  //       There might be a risk of infinite loop. Looping over
  //       pending transactions and removing only the first one
  //       that's mined, setting the new list, which will trigger
  //       the subscribe again, and so on... it's a no-go.
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

  // TODO: look into this one
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
