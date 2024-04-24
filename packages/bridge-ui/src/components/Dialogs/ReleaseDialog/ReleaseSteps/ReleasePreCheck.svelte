<script lang="ts">
  import { switchChain } from '@wagmi/core';
  import { t } from 'svelte-i18n';

  import { ActionButton } from '$components/Button';
  import { Icon } from '$components/Icon';
  import type { BridgeTransaction } from '$libs/bridge';
  import { getChainName } from '$libs/chain';
  import { config } from '$libs/wagmi';
  import { account } from '$stores/account';
  import { connectedSourceChain, switchingNetwork } from '$stores/network';

  export let tx: BridgeTransaction;

  export let canContinue = false;
  export let hideContinueButton = false;

  const switchChains = async () => {
    $switchingNetwork = true;
    try {
      await switchChain(config, { chainId: Number(tx.srcChainId) });
    } catch (err) {
      console.error(err);
    } finally {
      $switchingNetwork = false;
    }
  };

  $: txDestChainName = getChainName(Number(tx.destChainId));

  $: correctChain = Number(tx.srcChainId) === $connectedSourceChain.id;

  $: if (correctChain && $account) {
    hideContinueButton = false;
    canContinue = true;
  } else {
    hideContinueButton = true;
    canContinue = false;
  }
</script>

<div class="space-y-[25px] mt-[20px]">
  <div class="flex justify-between mb-2 items-center">
    <div class="font-bold text-primary-content">{$t('transactions.claim.steps.pre_check.title')}</div>
  </div>
  <div class="min-h-[150px] grid content-between">
    <div>
      <div class="f-between-center">
        <span class="text-secondary-content">{$t('transactions.claim.steps.pre_check.chain_check')}</span>
        {#if correctChain}
          <Icon type="check-circle" fillClass="fill-positive-sentiment" />
        {:else}
          <Icon type="x-close-circle" fillClass="fill-negative-sentiment" />
        {/if}
      </div>
    </div>
  </div>
  {#if !canContinue && !correctChain}
    <div class="h-sep" />
    <div class="f-col space-y-[16px]">
      <ActionButton
        onPopup
        priority="primary"
        disabled={$switchingNetwork}
        loading={$switchingNetwork}
        on:click={() => {
          switchChains();
        }}>{$t('common.switch_to')} {txDestChainName}</ActionButton>
    </div>
  {/if}
</div>
