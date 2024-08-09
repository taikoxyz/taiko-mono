<script lang="ts">
  import { t } from 'svelte-i18n';

  import AddressInput from '$components/Bridge/SharedBridgeComponents/AddressInput/AddressInput.svelte';
  import { AddressInputState } from '$components/Bridge/SharedBridgeComponents/AddressInput/state';
  import ActionButton from '$components/Button/ActionButton.svelte';
  import Card from '$components/Card/Card.svelte';
  import OnAccount from '$components/OnAccount/OnAccount.svelte';
  import { FungibleTransactionRow, NftTransactionRow } from '$components/Transactions/Rows';
  import { type BridgeTransaction, fetchTransactions, MessageStatus } from '$libs/bridge';
  import { TokenType } from '$libs/token';
  import { getLogger } from '$libs/util/logger';
  import { type Account, account } from '$stores/account';

  const log = getLogger('RelayerComponent');

  let transactions: BridgeTransaction[] = [];
  let fetching = false;
  let addressState = AddressInputState.DEFAULT;

  const onAccountChange = async (newAccount: Account, oldAccount?: Account) => {
    // We want to make sure that we are connected and only
    // fetch if the account has changed
    if (newAccount && newAccount.address && newAccount.address !== oldAccount?.address) {
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
  title={$t('relayer_component.title')}
  class="container f-col md:w-[768px]"
  text={$t('relayer_component.description')}>
  <div class="f-col space-y-[35px]">
    <span class="mt-[30px]">{$t('relayer_component.step1.title')}</span>

    {transactions?.length}
    {transactionsToShow?.length}
    <AddressInput
      labelText={$t('relayer_component.address_input_label')}
      isDisabled={inputDisabled}
      bind:ethereumAddress={addressToSearch}
      bind:state={addressState} />

    <div class="h-sep" />
    <span>{$t('relayer_component.step2.title')}</span>
    <ActionButton
      on:click={fetchTxForAddress}
      priority="primary"
      class="w-full"
      label="Search"
      loading={fetching}
      disabled={searchDisabled}>Search transactions</ActionButton>
    {#if transactionsToShow.length === 0}
      <div class="text-center">{$t('relayer_component.no_tx_found')}</div>
    {:else}
      <div class="h-sep" />
    {/if}
  </div>

  {#each transactionsToShow as bridgeTx (bridgeTx.srcTxHash)}
    {@const status = bridgeTx.msgStatus}
    {@const isFungible = bridgeTx.tokenType === TokenType.ERC20 || bridgeTx.tokenType === TokenType.ETH}
    {#if isFungible}
      <FungibleTransactionRow bind:bridgeTx {handleTransactionRemoved} bridgeTxStatus={status} />
    {:else}
      <NftTransactionRow bind:bridgeTx {handleTransactionRemoved} bridgeTxStatus={status} />
    {/if}
    <div class="h-sep !my-0 display-inline" />
  {/each}
</Card>

<OnAccount change={onAccountChange} />
