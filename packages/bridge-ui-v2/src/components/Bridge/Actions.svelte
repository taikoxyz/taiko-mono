<script>
  import { noop } from 'svelte/internal';
  import { t } from 'svelte-i18n';

  import { Button } from '$components/Button';
  import { Icon } from '$components/Icon';
  import { insufficientAllowance } from './state';

  export let approve = noop;
  export let bridge = noop;

  let approving = false;
  let bridging = false;

  function onApproveClick() {
    approving = true;
    approve().finally(() => {
      approving = false;
    });
  }

  function onBridgeClick() {
    bridging = true;
    bridge().finally(() => {
      bridging = false;
    });
  }

  $: showSteps = true;

  $: cannotBridge = true;

  $: loading = approving || bridging;
</script>

<div class="f-between-center w-full gap-4">
  {#if showSteps}
    <Button
      type="primary"
      class="px-[28px] py-[14px] rounded-full flex-1"
      disabled={!$insufficientAllowance || approving}
      loading={approving}
      on:click={onApproveClick}>
      {#if approving}
        <span class="body-bold">{$t('bridge.button.approving')}</span>
      {:else if !$insufficientAllowance}
        <div class="f-items-center">
          <Icon type="check" />
          <span class="body-bold">{$t('bridge.button.approved')}</span>
        </div>
      {:else}
        <span class="body-bold">{$t('bridge.button.approve')}</span>
      {/if}
    </Button>
    <Icon type="arrow-right" />
  {/if}

  <Button
    type="primary"
    class="px-[28px] py-[14px] rounded-full flex-1"
    disabled={cannotBridge || bridging}
    loading={bridging}
    on:click={onBridgeClick}>
    {#if bridging}
      <span class="body-bold">{$t('bridge.button.briding')}</span>
    {:else}
      <span class="body-bold">{$t('bridge.button.bridge')}</span>
    {/if}
  </Button>
</div>
