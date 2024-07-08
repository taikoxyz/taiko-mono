<script lang="ts">
  import { getBalance, switchChain } from '@wagmi/core';
  import { createEventDispatcher, onMount } from 'svelte';
  import { t } from 'svelte-i18n';
  import { type Address, getAddress, parseEther } from 'viem';

  import Alert from '$components/Alert/Alert.svelte';
  import { ActionButton } from '$components/Button';
  import { Icon } from '$components/Icon';
  import Spinner from '$components/Spinner/Spinner.svelte';
  import { Tooltip } from '$components/Tooltip';
  import { claimConfig } from '$config';
  import { type BridgeTransaction } from '$libs/bridge';
  import { checkEnoughBridgeQuotaForClaim } from '$libs/bridge/checkBridgeQuota';
  import { getChainName, isL2Chain } from '$libs/chain';
  import { shortenAddress } from '$libs/util/shortenAddress';
  import { config } from '$libs/wagmi';
  import { account } from '$stores/account';
  import { connectedSourceChain, switchingNetwork } from '$stores/network';

  export let tx: BridgeTransaction;
  export let canContinue = false;
  export let hideContinueButton = false;

  export const closeDialog = () => {
    dispatch('closeDialog');
  };

  const dispatch = createEventDispatcher();

  let checkingPrerequisites: boolean;

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

    const balance = await getBalance(config, { address, chainId });

    if (balance.value >= parseEther(String(claimConfig.minimumEthToClaim))) {
      return true;
    }
    return false;
  };

  const checkConditions = async () => {
    checkingPrerequisites = true;

    const results = await Promise.allSettled([
      checkEnoughBalance($account.address, Number(tx.destChainId)),
      checkEnoughBridgeQuotaForClaim({
        transaction: tx,
        amount: tx.amount,
      }),
    ]);

    results.forEach((result, index) => {
      if (result.status === 'fulfilled') {
        if (index === 0) {
          hasEnoughEth = result.value;
        } else if (index === 1) {
          hasEnoughQuota = result.value;
        }
      } else {
        // You can log or handle errors here if a promise was rejected.
        console.error(`Error in promise at index ${index}:`, result.reason);
      }
    });
    checkingPrerequisites = false;
  };

  $: txDestChainName = getChainName(Number(tx.destChainId));

  $: correctChain = Number(tx.destChainId) === $connectedSourceChain.id;

  $: successFullPreChecks = correctChain && hasEnoughEth && hasEnoughQuota;

  $: if (!checkingPrerequisites && successFullPreChecks && $account && !onlyDestOwnerCanClaimWarning) {
    hideContinueButton = false;
    canContinue = true;
  } else {
    if (!correctChain) {
      hideContinueButton = true;
    }
    canContinue = false;
  }

  $: $account && checkConditions();

  $: hasEnoughEth = false;
  $: hasEnoughQuota = false;

  $: hasPaidProcessingFee = tx.processingFee > 0;

  $: onlyDestOwnerCanClaimWarning = false;
  $: if (tx.message?.to && $account?.address && tx.message.destOwner) {
    const destOwnerMustClaim = tx.message.gasLimit === 0; // If gasLimit is 0, the destOwner must claim
    const isDestOwner = getAddress($account.address) === getAddress(tx.message.destOwner);

    if (destOwnerMustClaim && !isDestOwner) {
      onlyDestOwnerCanClaimWarning = true;
    } else {
      onlyDestOwnerCanClaimWarning = false;
    }
  }

  onMount(() => {
    checkConditions();
  });
</script>

<div class="space-y-[25px] mt-[20px]">
  <div class="flex justify-between mb-2 items-center">
    <div class="font-bold text-primary-content">{$t('transactions.claim.steps.pre_check.title')}</div>
  </div>
  <div class="min-h-[150px] grid content-between">
    {#if onlyDestOwnerCanClaimWarning}
      <div class="f-between-center">
        <div class="f-row gap-1">
          <div class="f-col">
            <Alert type="info"
              >{$t('transactions.claim.steps.pre_check.different_recipient')}
              <div class="h-sep" />
              <span class="font-bold">{$t('common.recipient')}: </span>{shortenAddress(tx.message?.destOwner, 6, 4)}
            </Alert>
          </div>
        </div>
        {#if checkingPrerequisites}
          <Spinner />
        {:else}
          <Icon type="x-close-circle" fillClass="fill-negative-sentiment" />
        {/if}
      </div>
    {:else}
      <div>
        <div class="f-between-center">
          <div class="f-row gap-1">
            <span class="text-secondary-content">{$t('transactions.claim.steps.pre_check.chain_check')}</span>
            <Tooltip>
              <h2>{$t('transactions.claim.steps.pre_check.tooltip.chain.title')}</h2>

              <span>{$t('transactions.claim.steps.pre_check.tooltip.chain.description')}</span>
            </Tooltip>
          </div>
          {#if checkingPrerequisites}
            <Spinner />
          {:else if correctChain}
            <Icon type="check-circle" fillClass="fill-positive-sentiment" />
          {:else}
            <Icon type="x-close-circle" fillClass="fill-negative-sentiment" />
          {/if}
        </div>
        <div class="f-between-center">
          <div class="f-row gap-1">
            <span class="text-secondary-content">{$t('transactions.claim.steps.pre_check.funds_check')}</span>
            <Tooltip>
              <h2>{$t('transactions.claim.steps.pre_check.tooltip.funds.title')}</h2>
              <span>{$t('transactions.claim.steps.pre_check.tooltip.funds.description')} </span>
            </Tooltip>
          </div>
          {#if checkingPrerequisites}
            <Spinner />
          {:else if hasEnoughEth}
            <Icon type="check-circle" fillClass="fill-positive-sentiment" />
          {:else}
            <Icon type="x-close-circle" fillClass="fill-negative-sentiment" />
          {/if}
        </div>
        {#if isL2Chain(Number(tx.srcChainId))}
          <div class="f-between-center">
            <div class="f-row gap-1">
              <span class="text-secondary-content">{$t('transactions.claim.steps.pre_check.quota_check')}</span>
              <Tooltip>
                <h2>{$t('transactions.claim.steps.pre_check.tooltip.quota.title')}</h2>
                <span>{$t('transactions.claim.steps.pre_check.tooltip.quota.description')} </span>
              </Tooltip>
            </div>
            {#if checkingPrerequisites}
              <Spinner />
            {:else if hasEnoughQuota}
              <Icon type="check-circle" fillClass="fill-positive-sentiment" />
            {:else}
              <Icon type="x-close-circle" fillClass="fill-negative-sentiment" />
            {/if}
          </div>
        {/if}
        {#if hasPaidProcessingFee}
          <div class="h-sep" />
          <div class="f-between-center">
            {#if checkingPrerequisites}
              <Spinner />
            {:else}
              <Alert type="info">{$t('transactions.claim.steps.pre_check.tooltip.processing_fee.description')}</Alert>
            {/if}
          </div>
        {/if}
      </div>
    {/if}
  </div>
  {#if !canContinue && !correctChain && !onlyDestOwnerCanClaimWarning}
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
  {:else if !canContinue}
    <div class="h-sep" />
    <div class="f-col space-y-[16px]">
      <ActionButton
        onPopup
        priority="primary"
        on:click={() => {
          closeDialog();
        }}>{$t('common.ok')}</ActionButton>
    </div>
  {/if}
</div>
