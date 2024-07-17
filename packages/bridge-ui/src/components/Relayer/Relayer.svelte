<script lang="ts">
  import AddressInput from '$components/Bridge/SharedBridgeComponents/AddressInput/AddressInput.svelte';
  import { AddressInputState } from '$components/Bridge/SharedBridgeComponents/AddressInput/state';
  import ActionButton from '$components/Button/ActionButton.svelte';
  import Card from '$components/Card/Card.svelte';
  import OnAccount from '$components/OnAccount/OnAccount.svelte';
  import Transaction from '$components/Transactions/Transaction.svelte';
  import { type BridgeTransaction, fetchTransactions, MessageStatus } from '$libs/bridge';
  import { getLogger } from '$libs/util/logger';
  import { type Account, account } from '$stores/account';

  const log = getLogger('RelayerComponent');

  let transactions: BridgeTransaction[] = [];
  let fetching = false;
  let addressState = AddressInputState.DEFAULT;

  const onAccountChange = async (newAccount: Account, oldAccount?: Account) => {
    // We want to make sure that we are connected and only
    // fetch if the account has changed
    if (newAccount.address && newAccount.address !== oldAccount?.address) {
      reset();
    }
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
      const { mergedTransactions } = await fetchTransactions(addressToSearch);
      log('mergedTransactions', mergedTransactions);
      if (mergedTransactions.length > 0) {
        transactions = mergedTransactions;
      }
    }
    fetching = false;
  };

  const handleTransactionRemoved = (event: CustomEvent<{ transaction: BridgeTransaction }>) => {
    log('handleTransactionRemoved', event.detail.transaction);
    transactions = transactions.filter((tx) => tx !== event.detail.transaction);
  };

  $: inputDisabled = fetching || !$account?.isConnected;

  $: addressToSearch = undefined;
  $: searchDisabled = fetching || !addressToSearch || addressState !== AddressInputState.VALID || inputDisabled;

  $: transactionsToShow = transactions.filter((tx) => {
    const gasLimitZero = tx.message?.gasLimit === 0;
    const userIsRecipientOrDestOwner =
      tx.message?.to === $account?.address || tx.message?.destOwner === $account?.address;
    if (tx.status === MessageStatus.NEW) {
      if (gasLimitZero && userIsRecipientOrDestOwner) {
        return tx;
      } else if (!gasLimitZero) {
        return tx;
      } else if (gasLimitZero && !userIsRecipientOrDestOwner) {
        console.warn('gaslimit set to zero, not claimable by connected wallet', tx);
      }
    }
  });
</script>

<Card
  title="Relayer Component"
  class="container f-col md:w-[768px]"
  text="This component allows you to manually claim transactions that are not your own">
  <div class="f-col space-y-[35px]">
    <span class="mt-[30px]">Step 1: Select the recipient</span>

    <AddressInput
      labelText="Enter the recipient address"
      isDisabled={inputDisabled}
      bind:ethereumAddress={addressToSearch}
      bind:state={addressState} />

    <div class="h-sep" />
    <span>Step 2: Search the transaction you want</span>
    <ActionButton
      on:click={fetchTxForAddress}
      priority="primary"
      class="w-full"
      label="Search"
      loading={fetching}
      disabled={searchDisabled}>Search transactions</ActionButton>
    {#if transactionsToShow.length === 0}
      <div class="text-center">No claimable transactions found</div>
    {:else}
      <div class="h-sep" />
    {/if}
  </div>
  {#each transactionsToShow as tx}
    {#if tx.status === MessageStatus.NEW}
      <Transaction item={tx} {handleTransactionRemoved} bind:bridgeTxStatus={tx.status} />
    {/if}
  {/each}
</Card>

<OnAccount change={onAccountChange} />
