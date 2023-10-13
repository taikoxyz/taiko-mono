<script lang="ts">
  import { t } from 'svelte-i18n';

  import { Button } from '$components/Button';
  import { Icon } from '$components/Icon';
  import { type NFT, TokenType } from '$libs/token';
  import { account, network } from '$stores';

  import {
    computingBalance,
    destNetwork,
    enteredAmount,
    errorComputingBalance,
    insufficientAllowance,
    insufficientBalance,
    notApproved,
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

  $: isTokenApproved =
    $selectedToken?.type === TokenType.ERC20
      ? isSelectedERC20 && $enteredAmount && !$insufficientAllowance && !$validatingAmount
      : $selectedToken?.type === TokenType.ERC721 || $selectedToken?.type === TokenType.ERC1155
      ? allTokensApproved
      : false;

  // Check if all NFTs are approved
  $: allTokensApproved =
    $selectedToken?.type === TokenType.ERC721 || $selectedToken?.type === TokenType.ERC1155
      ? $notApproved.get(($selectedToken as NFT).tokenId)
      : false;

  // Conditions to disable/enable buttons
  $: disableApprove =
    $selectedToken?.type === TokenType.ERC20
      ? canDoNothing || $insufficientBalance || $validatingAmount || approving || isTokenApproved
      : $selectedToken?.type === TokenType.ERC721
      ? allTokensApproved || approving
      : $selectedToken?.type === TokenType.ERC1155
      ? allTokensApproved || approving
      : approving;

  $: disableBridge =
    $selectedToken?.type === TokenType.ERC20
      ? canDoNothing || $insufficientAllowance || $insufficientBalance || $validatingAmount || bridging
      : $selectedToken?.type === TokenType.ERC721 || $selectedToken?.type === TokenType.ERC1155
      ? !allTokensApproved
      : bridging || !hasAddress || !hasNetworks || !hasBalance || !$selectedToken || !$enteredAmount;
</script>

<div class="f-between-center w-full gap-4">
  {#if $selectedToken && $selectedToken.type !== TokenType.ETH}
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
    class="px-[28px] py-[14px] rounded-full flex-1 text-white"
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
