<script lang="ts">
  import type { FetchBalanceResult } from '@wagmi/core';
  import { t } from 'svelte-i18n';
  import { formatEther, parseUnits } from 'viem';

  import { InputBox } from '$components/InputBox';
  import { getMaxToBridge } from '$libs/bridge/getMaxToBridge';
  import { uid } from '$libs/util/uid';
  import { account } from '$stores/account';
  import { network } from '$stores/network';

  import { destNetwork, enteredAmount, processingFee, selectedToken } from '../state';
  import Balance from './Balance.svelte';
  import { warningToast } from '$components/NotificationToast';

  let inputId = `input-${uid()}`;
  let tokenBalance: FetchBalanceResult;
  let inputBox: InputBox;

  let computingMaxAmount = false;
  let errorAmount = false;

  // Handler for when the user leaves the amount input.
  // Will inform the users if they have enough balance to bridge
  // the amount they entered
  async function checkAmount() {
    if (!$selectedToken || !$network || !$account?.address) return;

    const maxAmount = await getMaxToBridge({
      token: $selectedToken,
      balance: tokenBalance.value,
      processingFee: $processingFee,
      srcChainId: $network.id,
      destChainId: $destNetwork?.id,
      userAddress: $account.address,
      amount: $enteredAmount,
    });

    if ($enteredAmount > maxAmount) {
      errorAmount = true;
    }
  }

  // Handle for when the user changes the amount input.
  // Will update the entered amount in the store
  function updateAmount(event: Event) {
    errorAmount = false;

    if (!$selectedToken) return;

    const target = event.target as HTMLInputElement;

    try {
      $enteredAmount = parseUnits(target.value, $selectedToken?.decimals);
    } catch (err) {
      $enteredAmount = BigInt(0);
    }
  }

  function setETHAmount(amount: bigint) {
    inputBox.setValue(formatEther(amount));
    $enteredAmount = amount;
  }

  // We call this function when clicking on the "MAX" button
  async function useMaxAmount() {
    if (!$selectedToken || !$network || !$account?.address) return;

    computingMaxAmount = true;

    try {
      const maxAmount = await getMaxToBridge({
        token: $selectedToken,
        balance: tokenBalance.value,
        processingFee: $processingFee,
        srcChainId: $network.id,
        destChainId: $destNetwork?.id,
        userAddress: $account.address,
      });

      setETHAmount(maxAmount);
    } catch (err) {
      console.error(err);
      warningToast($t('amount_input.button.failed_max'));
    } finally {
      computingMaxAmount = false;
    }
  }
</script>

<div class="AmountInput f-col space-y-2">
  <div class="f-between-center text-secondary-content">
    <label class="body-regular" for={inputId}>{$t('amount_input.label')}</label>
    <Balance bind:value={tokenBalance} />
  </div>
  <div class="relative f-items-center">
    <InputBox
      id={inputId}
      type="number"
      placeholder="0.01"
      min="0"
      loading={computingMaxAmount}
      on:input={updateAmount}
      bind:this={inputBox}
      class="w-full input-box outline-none py-6 pr-16 px-[26px] title-subsection-bold placeholder:text-tertiary-content" />
    <button
      class="absolute right-6 uppercase"
      disabled={!$selectedToken || !$network || computingMaxAmount}
      on:click={useMaxAmount}>
      {$t('amount_input.button.max')}
    </button>
  </div>
</div>
