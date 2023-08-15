<script lang="ts">
  import { t } from 'svelte-i18n';

  import { Button } from '$components/Button';
  import { Icon } from '$components/Icon';
  import { TokenType } from '$libs/token';
  import { account, network } from '$stores';

  import {
    computingBalance,
    destNetwork,
    enteredAmount,
    errorComputingBalance,
    insufficientAllowance,
    insufficientBalance,
    recipientAddress,
    selectedToken,
    tokenBalance,
    validatingAmount,
  } from './state';

  export let approve: () => Promise<void>;
  export let bridge: () => Promise<void>;

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

  // TODO: feels like we need a state machine here

  // Basic conditions so we can even start the bridging process
  $: hasAddress = $recipientAddress || $account?.address;
  $: hasNetworks = $network?.id && $destNetwork?.id;
  $: hasBalance =
    !$computingBalance && !$errorComputingBalance && $tokenBalance?.value && $tokenBalance?.value > BigInt(0);
  $: canDoNothing = !hasAddress || !hasNetworks || !hasBalance || !$selectedToken || !$enteredAmount;

  // Conditions for approve/bridge steps
  $: isSelectedERC20 = $selectedToken && $selectedToken.type === TokenType.ERC20;
  $: isTokenApproved = isSelectedERC20 && $enteredAmount && !$insufficientAllowance && !$validatingAmount;

  // Conditions to disable/enable buttons
  $: disableApprove = canDoNothing || !$insufficientAllowance || $validatingAmount || approving;
  $: disableBridge = canDoNothing || $insufficientAllowance || $insufficientBalance || $validatingAmount || bridging;

  // General loading state
  // $: loading = approving || bridging;
</script>

<div class="f-between-center w-full gap-4">
  {#if isSelectedERC20}
    <Button
      type="primary"
      class="px-[28px] py-[14px] rounded-full flex-1"
      disabled={disableApprove}
      loading={approving}
      on:click={onApproveClick}>
      {#if approving}
        <span class="body-bold">{$t('bridge.button.approving')}</span>
      {:else if isTokenApproved}
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
    disabled={disableBridge}
    loading={bridging}
    on:click={onBridgeClick}>
    {#if bridging}
      <span class="body-bold">{$t('bridge.button.bridging')}</span>
    {:else}
      <span class="body-bold">{$t('bridge.button.bridge')}</span>
    {/if}
  </Button>
</div>
