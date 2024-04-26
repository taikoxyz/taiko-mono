<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import type { Hash } from 'viem';

  import { chainConfig } from '$chainConfig';
  import ActionButton from '$components/Button/ActionButton.svelte';
  import { Icon, type IconType } from '$components/Icon';
  import { Spinner } from '$components/Spinner';
  import type { BridgeTransaction } from '$libs/bridge';
  import { theme } from '$stores/theme';

  export let canClaim = false;

  export let claimingDone = false;

  export let claiming = false;

  export let bridgeTx: BridgeTransaction;

  export let txHash: Hash;

  const dispatch = createEventDispatcher();

  const handleClaimClick = async () => {
    dispatch('claim');
  };

  const getSuccessTitle = () => {
    return $t('bridge.step.confirm.success.claim');
  };

  const getSuccessDescription = () => {
    if (!txHash) return;

    const explorer = chainConfig[Number(bridgeTx.destChainId)]?.blockExplorers?.default.url;
    const url = `${explorer}/tx/${txHash}`;

    successDescription = $t('transactions.actions.claim.success.message', { values: { url } });
  };

  $: if (txHash && claimingDone) {
    getSuccessDescription();
  }

  $: bridgeIcon = `bridge-${$theme}` as IconType;
  $: successIcon = `success-${$theme}` as IconType;

  $: statusTitle = getSuccessTitle();
  let successDescription = '';

  $: claimDisabled = !canClaim || claiming;
</script>

<div class="space-y-[18px]">
  <div class="mt-[30px]">
    <section id="txStatus">
      <div class="flex flex-col justify-content-center items-center">
        {#if claimingDone}
          <Icon type={successIcon} size={160} />
          <div id="text" class="f-col my-[30px] text-center">
            <!-- eslint-disable-next-line svelte/no-at-html-tags -->
            <h1>{@html statusTitle}</h1>
            <!-- eslint-disable-next-line svelte/no-at-html-tags -->
            <span class="">{@html successDescription}</span>
          </div>
        {:else if claiming}
          <Spinner class="!w-[160px] !h-[160px] text-primary-brand" />
          <div id="text" class="f-col my-[30px] text-center">
            <h1 class="mb-[16px]">{$t('bridge.step.confirm.processing')}</h1>
            <span>{$t('bridge.step.confirm.approve.pending')}</span>
          </div>
        {:else if !claiming && !claimingDone}
          <Icon type={bridgeIcon} size={160} />
          <div id="text" class="f-col my-[30px] text-center">
            <h1 class="mb-[16px]">{$t('transactions.claim.steps.confirm.proceed')}</h1>
            <span>{$t('transactions.claim.steps.confirm.claim_description')}</span>
          </div>
        {/if}
      </div>
    </section>
    {#if !claimingDone}
      <section id="actions" class="f-col w-full">
        <div class="h-sep mb-[30px]" />
        <ActionButton
          onPopup
          priority="primary"
          loading={claiming}
          on:click={() => handleClaimClick()}
          disabled={claimDisabled}>{$t('transactions.claim.steps.confirm.claim_button')}</ActionButton>
      </section>
    {/if}
  </div>
</div>
