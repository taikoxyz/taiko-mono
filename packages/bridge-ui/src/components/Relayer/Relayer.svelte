<script lang="ts">
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import AddressInput from '$components/Bridge/SharedBridgeComponents/AddressInput/AddressInput.svelte';
  import { AddressInputState } from '$components/Bridge/SharedBridgeComponents/AddressInput/state';
  import ActionButton from '$components/Button/ActionButton.svelte';
  import Card from '$components/Card/Card.svelte';
  import { warningToast } from '$components/NotificationToast';
  import OnAccount from '$components/OnAccount/OnAccount.svelte';
  import { getLoadWarning } from '$components/Transactions/loadWarning';
  import { FungibleTransactionRow, NftTransactionRow } from '$components/Transactions/Rows';
  import { type BridgeTransaction, fetchTransactions, MessageStatus } from '$libs/bridge';
  import { bridgeTxKey } from '$libs/bridge/bridgeTxIdentity';
  import { loadFailureMessageKey } from '$libs/bridge/loadFailureMessage';
  import { TokenType } from '$libs/token';
  import { getLogger } from '$libs/util/logger';
  import { type Account, account } from '$stores/account';

  const log = getLogger('RelayerComponent');

  let transactions: BridgeTransaction[] = [];
  let fetching = false;
  let addressState = AddressInputState.DEFAULT;
  /**
   * Two-way bound to the address input. A plain declaration, not a reactive one: as
   * `$: addressToSearch = undefined` it ran once on mount and looked deliberate, but any
   * dependency added to that statement later would have re-run it on every change and
   * wiped the search - taking the results with it through the clear below.
   */
  let addressToSearch: string | undefined = undefined;

  const onAccountChange = async (newAccount: Account, oldAccount?: Account) => {
    // Any change of address resets, including a transition to no address: a search
    // started while connected must not publish rows into a disconnected view
    if (newAccount?.address !== oldAccount?.address) {
      reset();
    }
  };
  // Only the most recent search may write results, an error, or clear the loading flag:
  // switching accounts mid-fetch would otherwise let the previous address's response
  // repopulate the table and turn off the spinner belonging to the newer search.
  let searchGeneration = 0;

  const reset = () => {
    log('reset');
    searchGeneration++;
    transactions = [];
    fetching = false;
    addressState = AddressInputState.DEFAULT;
    transactionsToShow = [];
    addressToSearch = undefined;
    searchDisabled = true;
  };

  const fetchTxForAddress = async () => {
    log('fetchTxForAddress');
    const generation = ++searchGeneration;
    fetching = true;
    try {
      if (addressToSearch) {
        // Cast, not a check: the Search button is disabled until addressState is VALID,
        // so nothing reaches here that the address input has not already validated
        const { mergedTransactions, error, failedCount } = await fetchTransactions(addressToSearch as Address);
        if (generation !== searchGeneration) return;
        log('mergedTransactions', mergedTransactions);
        // Also assign empty results: the previous address's transactions must not linger
        transactions = mergedTransactions;
        // Neither signal reaches the catch below: a relayer failure is reported rather than
        // thrown, and a message the relayer returned but could not be read on-chain is simply
        // absent from the list with nothing to mark it. Without both, a failed search looked
        // like an address with no transactions and a partial one like a complete short history.
        // The same decision as the transactions page, taken in the same place, so the two
        // cannot drift.
        const warning = getLoadWarning({ error, failedCount });
        if (warning) {
          if (error) console.error('Error fetching transactions', error);
          warningToast({ title: $t(warning.key, { values: warning.values }) });
        }
      }
    } catch (error) {
      if (generation !== searchGeneration) return;
      console.error('Error fetching transactions', error);
      warningToast({ title: $t(loadFailureMessageKey(error)) });
    } finally {
      if (generation === searchGeneration) fetching = false;
    }
  };

  const handleTransactionRemoved = (event: CustomEvent<{ transaction: BridgeTransaction }>) => {
    log('handleTransactionRemoved', event.detail.transaction);
    transactions = transactions.filter((tx) => tx !== event.detail.transaction);
  };

  $: inputDisabled = fetching || !$account?.isConnected;

  // No address, no results: rows from a previously searched address must not linger.
  // Bumping the generation matters as much as clearing: a fetch for the address that was
  // just erased is still in flight, and without this its response still matches and
  // repopulates the table for an address no longer on screen.
  $: if (!addressToSearch) {
    searchGeneration++;
    transactions = [];
    // Superseding the in-flight fetch also orphans its `finally`, which only lowers this
    // for the generation it belongs to. Left set, the address field stays disabled for
    // good - the search cleared, and no way to start another one.
    fetching = false;
  }

  $: searchDisabled = fetching || !addressToSearch || addressState !== AddressInputState.VALID || inputDisabled;

  $: transactionsToShow = transactions.filter((tx) => {
    const gasLimitZero = tx.message?.gasLimit === 0;
    const userIsRecipientOrDestOwner =
      tx.message?.to === $account?.address || tx.message?.destOwner === $account?.address;
    if (tx.status === MessageStatus.NEW || tx.status === MessageStatus.RETRIABLE) {
      if (gasLimitZero) {
        if (userIsRecipientOrDestOwner) {
          return tx;
        } else {
          console.warn('gaslimit set to zero, not claimable by connected wallet', tx);
        }
      } else {
        return tx;
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

  {#each transactionsToShow as bridgeTx (bridgeTxKey(bridgeTx))}
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
