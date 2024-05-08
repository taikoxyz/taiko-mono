<script lang="ts">
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import {
    allApproved,
    computingBalance,
    destNetwork,
    enteredAmount,
    errorComputingBalance,
    insufficientAllowance,
    insufficientBalance,
    recipientAddress,
    selectedToken,
    selectedTokenIsBridged,
    tokenBalance,
    validatingAmount,
  } from '$components/Bridge/state';
  import ActionButton from '$components/Button/ActionButton.svelte';
  import { Icon } from '$components/Icon';
  import { BridgePausedError } from '$libs/error';
  import { TokenType } from '$libs/token';
  import { getTokenApprovalStatus } from '$libs/token/getTokenApprovalStatus';
  import { account, connectedSourceChain } from '$stores';

  export let approve: () => Promise<void>;
  export let bridge: () => Promise<void>;

  export let approving = false;
  export let bridging = false;

  export let disabled = false;

  let paused = false;
  export let checking = false;

  function onApproveClick() {
    if (paused) throw new BridgePausedError('Bridge is paused');
    approving = true;
    approve().finally(() => {
      approving = false;
    });
  }

  function onBridgeClick() {
    if (paused) throw new BridgePausedError('Bridge is paused');
    bridging = true;
    bridge();
  }

  onMount(async () => {
    if ($selectedToken) {
      $allApproved = false;
      checking = true;
      if ($selectedTokenIsBridged) {
        $allApproved = true;
        $insufficientAllowance = false;
      } else {
        await getTokenApprovalStatus($selectedToken);
      }
      checking = false;
    }
  });

  $: isValidBalance = isETH || isERC20 || isERC1155 ? $tokenBalance && $tokenBalance.value > 0n : isERC721;

  // Basic conditions so we can even start the bridging process
  $: hasAddress = $recipientAddress || Boolean($account?.address);
  $: hasNetworks = $connectedSourceChain?.id && $destNetwork?.id;
  $: hasBalance = !$insufficientBalance && !$computingBalance && !$errorComputingBalance && isValidBalance;

  $: canDoNothing = !hasAddress || !hasNetworks || !hasBalance || !$selectedToken || disabled;

  const isERC20ApprovalDisabled = () => {
    return canDoNothing || $insufficientBalance || $validatingAmount || approving || $allApproved || !$enteredAmount;
  };

  const isERC721ApprovalDisabled = () => {
    return $allApproved || approving;
  };

  const isERC1155ApprovalDisabled = () => {
    return $allApproved || approving;
  };

  const checkDisableApprove = () => {
    if (checking) return true;
    if (!$selectedTokenIsBridged) {
      switch (true) {
        case isERC20:
          return isERC20ApprovalDisabled();
        case isERC721:
          return isERC721ApprovalDisabled();
        case isERC1155:
          return isERC1155ApprovalDisabled();
      }
    }
    return approving;
  };

  // Conditions to disable/enable buttons
  $: disableApprove = checkDisableApprove();

  $: isERC20 = $selectedToken?.type === TokenType.ERC20;
  $: isERC721 = $selectedToken?.type === TokenType.ERC721;
  $: isERC1155 = $selectedToken?.type === TokenType.ERC1155;
  $: isETH = $selectedToken?.type === TokenType.ETH;

  $: validApprovalStatus = $selectedTokenIsBridged || $allApproved;

  $: commonConditions =
    validApprovalStatus &&
    !bridging &&
    hasAddress &&
    hasNetworks &&
    hasBalance &&
    $selectedToken &&
    !$validatingAmount &&
    !$insufficientBalance &&
    $allApproved &&
    !paused;

  const isDisableBridge = () => {
    switch (true) {
      case isERC20:
        return !(commonConditions && !canDoNothing && !$insufficientAllowance && $tokenBalance && $enteredAmount);
      case isERC721:
        return !commonConditions;
      case isERC1155:
        return !(commonConditions && $enteredAmount && $enteredAmount > 0);
      case isETH:
        return !(commonConditions && $enteredAmount && $enteredAmount > 0);
      default:
        return !commonConditions;
    }
  };
</script>

<div class="f-col w-full gap-4">
  {#if $selectedToken && !isETH && !$selectedTokenIsBridged}
    <ActionButton
      priority="primary"
      disabled={disableApprove}
      loading={approving || $validatingAmount || checking}
      on:click={onApproveClick}>
      {#if approving}
        <span class="body-bold">{$t('bridge.button.approving')}</span>
      {:else if $allApproved}
        <div class="f-items-center">
          <Icon type="check" />
          <span class="body-bold">{$t('bridge.button.approved')}</span>
        </div>
      {:else if checking}
        <span class="body-bold">{$t('bridge.button.validating')}</span>
      {:else}
        <span class="body-bold">{$t('bridge.button.approve')}</span>
      {/if}
    </ActionButton>
  {/if}
  <ActionButton priority="primary" disabled={isDisableBridge()} loading={bridging} on:click={onBridgeClick}>
    {#if bridging}
      <span class="body-bold">{$t('bridge.button.bridging')}</span>
    {:else}
      <span class="body-bold">{$t('bridge.button.bridge')}</span>
    {/if}
  </ActionButton>
</div>
