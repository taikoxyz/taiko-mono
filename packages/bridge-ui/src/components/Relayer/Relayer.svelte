<script lang="ts">
  import type { Chain } from 'viem';

  import AddressInput from '$components/Bridge/SharedBridgeComponents/AddressInput/AddressInput.svelte';
  import { AddressInputState } from '$components/Bridge/SharedBridgeComponents/AddressInput/state';
  import ActionButton from '$components/Button/ActionButton.svelte';
  import Card from '$components/Card/Card.svelte';
  import ChainPill from '$components/ChainSelectors/ChainPill/ChainPill.svelte';
  import OnAccount from '$components/OnAccount/OnAccount.svelte';
  import Transaction from '$components/Transactions/Transaction.svelte';
  import { type BridgeTransaction, fetchTransactions, MessageStatus } from '$libs/bridge';
  import { getLogger } from '$libs/util/logger';
  import { connectedSourceChain } from '$stores/network';

  const log = getLogger('RelayerComponent');

  let transactions: BridgeTransaction[] = [];
  let fetching = false;
  let addressState = AddressInputState.DEFAULT;

  const onAccountChange = () => {
    reset();
  };

  const reset = () => {
    log('reset');
    transactions = [];
    fetching = false;
    addressState = AddressInputState.DEFAULT;
    transactionsToShow = [];
    addressToSearch = undefined;
    searchDisabled = true;
  };

  const fetchTxForAddress = async () => {
    log('fetchTxForAddress');
    fetching = true;
    if (addressToSearch) {
      const { mergedTransactions } = await fetchTransactions(addressToSearch, selectedChain.id);
      log('mergedTransactions', mergedTransactions);
      if (mergedTransactions.length > 0) {
        transactions = mergedTransactions;
      }
    }
    fetching = false;
  };

  const selectChain = async (event: CustomEvent<{ chain: Chain; switchWallet: boolean }>) => {
    log('selectedChain', event.detail.chain.id);
    selectedChain = event.detail.chain;
  };

  const handleTransactionRemoved = (event: CustomEvent<{ transaction: BridgeTransaction }>) => {
    log('handleTransactionRemoved', event.detail.transaction);
    transactions = transactions.filter((tx) => tx !== event.detail.transaction);
  };

  $: addressToSearch = undefined;
  $: searchDisabled = fetching || !addressToSearch || addressState !== AddressInputState.VALID;

  $: selectedChain = $connectedSourceChain;
  $: transactionsToShow = transactions.filter((tx) => tx.status === MessageStatus.NEW);
</script>

<Card
  title="Relayer Component"
  class="container f-col"
  text="This component allows you to manually claim transactions that are not your own">
  <div class="f-col space-y-[35px]">
    <span class="mt-[30px]">Step 1: Search the transaction you want to claim</span>

    <AddressInput
      label="Enter the recipient address"
      bind:ethereumAddress={addressToSearch}
      bind:state={addressState} />

    <ChainPill label="Chain the message was sent from" value={selectedChain} {selectChain} switchWallet={true} />

    <ActionButton
      on:click={fetchTxForAddress}
      priority="primary"
      class="w-full"
      label="Search"
      loading={fetching}
      disabled={searchDisabled}>Search transactions</ActionButton>

    <div class="h-sep" />
    <span>Step 2: Claim the transaction you want</span>

    {#if transactionsToShow.length === 0}
      <div class="text-center">No transactions found</div>
    {/if}
  </div>

  {#each transactionsToShow as tx}
    {#if tx.status === MessageStatus.NEW}
      <Transaction item={tx} {handleTransactionRemoved} bind:bridgeTxStatus={tx.status} />
    {/if}
  {/each}
</Card>

<OnAccount change={onAccountChange} />
