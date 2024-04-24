<script lang="ts">
  import { getBalance, switchChain } from '@wagmi/core';
  import { t } from 'svelte-i18n';
  import { type Address, parseEther } from 'viem';

  import { ActionButton } from '$components/Button';
  import { Icon } from '$components/Icon';
  import Spinner from '$components/Spinner/Spinner.svelte';
  import { claimConfig } from '$config';
  import type { BridgeTransaction } from '$libs/bridge';
  import { getChainName } from '$libs/chain';
  import { config } from '$libs/wagmi';
  import { account } from '$stores/account';
  import { connectedSourceChain, switchingNetwork } from '$stores/network';

  export let tx: BridgeTransaction;
  export let canContinue = false;
  export let checkingPrerequisites: boolean;
  export let hideContinueButton = false;

  const switchChains = async () => {
    $switchingNetwork = true;
    try {
      await switchChain(config, { chainId: Number(tx.destChainId) });
    } catch (err) {
      console.error(err);
    } finally {
      $switchingNetwork = false;
    }
  };

  const checkEnoughBalance = async (address: Maybe<Address>, chainId: number) => {
    if (!address) {
      return false;
    }
    checkingPrerequisites = true;

    const balance = await getBalance(config, { address, chainId });

    if (balance.value <= parseEther(String(claimConfig.minimumEthToClaim))) {
      hasEnoughEth = false;
    } else {
      hasEnoughEth = true;
    }

    checkingPrerequisites = false;
  };

  const checkConditions = async () => {
    await checkEnoughBalance($account.address, Number(tx.destChainId));
  };

  $: txDestChainName = getChainName(Number(tx.destChainId));

  $: correctChain = Number(tx.destChainId) === $connectedSourceChain.id;

  $: if (correctChain && !checkingPrerequisites && hasEnoughEth && $account) {
    hideContinueButton = false;
    canContinue = true;
  } else {
    if (!correctChain) {
      hideContinueButton = true;
    }
    canContinue = false;
  }

  $: $account && tx.destChainId, checkConditions();

  $: hasEnoughEth = false;
</script>

<div class="space-y-[25px] mt-[20px]">
  <div class="flex justify-between mb-2 items-center">
    <div class="font-bold text-primary-content">{$t('transactions.claim.steps.pre_check.title')}</div>
  </div>
  <div class="min-h-[150px] grid content-between">
    <div>
      <div class="f-between-center">
        <span class="text-secondary-content">{$t('transactions.claim.steps.pre_check.chain_check')}</span>
        {#if checkingPrerequisites}
          <Spinner />
        {:else if correctChain}
          <Icon type="check-circle" fillClass="fill-positive-sentiment" />
        {:else}
          <Icon type="x-close-circle" fillClass="fill-negative-sentiment" />
        {/if}
      </div>
      <div class="f-between-center">
        <span class="text-secondary-content">{$t('transactions.claim.steps.pre_check.funds_check')}</span>
        {#if checkingPrerequisites}
          <Spinner />
        {:else if hasEnoughEth}
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
