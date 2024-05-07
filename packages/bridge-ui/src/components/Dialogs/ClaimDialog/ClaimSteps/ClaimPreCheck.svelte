<script lang="ts">
  import { getBalance, readContract, switchChain } from '@wagmi/core';
  import { t } from 'svelte-i18n';
  import { type Address, parseEther, zeroAddress } from 'viem';

  import { quotaManagerAbi } from '$abi';
  import { ActionButton } from '$components/Button';
  import { Icon } from '$components/Icon';
  import Spinner from '$components/Spinner/Spinner.svelte';
  import { claimConfig } from '$config';
  import { type BridgeTransaction, ContractType } from '$libs/bridge';
  import { getContractAddressByType } from '$libs/bridge/getContractAddressByType';
  import { getChainName, isL2Chain } from '$libs/chain';
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

    const balance = await getBalance(config, { address, chainId });

    if (balance.value <= parseEther(String(claimConfig.minimumEthToClaim))) {
      hasEnoughEth = false;
    } else {
      hasEnoughEth = true;
    }
  };

  const checkBridgeQuota = async ({
    srcChainId,
    destChainId,
    tokenAddress = zeroAddress,
    amount,
  }: {
    srcChainId: number;
    destChainId: number;
    tokenAddress?: Address;
    amount: bigint;
  }) => {
    if (!isL2Chain(Number(tx.destChainId))) {
      // Quota only applies to L2 chains
      hasEnoughEth = true;
      return;
    }
    const quotaManagerAddress = getContractAddressByType({
      srcChainId,
      destChainId,
      contractType: ContractType.QUOTAMANAGER,
    });

    const quota = await readContract(config, {
      address: quotaManagerAddress,
      abi: quotaManagerAbi,
      chainId: Number(tx.destChainId),
      functionName: 'availableQuota',
      args: [tokenAddress, 0n],
    });
    if (amount > quota) {
      hasEnoughQuota = false;
    } else {
      hasEnoughQuota = true;
    }
  };

  const checkConditions = async () => {
    checkingPrerequisites = true;

    const checks = Promise.allSettled([
      checkEnoughBalance($account.address, Number(tx.destChainId)),
      checkBridgeQuota({
        srcChainId: Number(tx.srcChainId),
        destChainId: Number(tx.destChainId),
        tokenAddress: tx.canonicalTokenAddress,
        amount: tx.amount,
      }),
    ]);

    try {
      const results = await checks;
      results.forEach((result, index) => {
        if (result.status === 'fulfilled') {
          // eslint-disable-next-line no-console
          console.log(`Promise ${index} resolved with value:`, result.value);
        } else {
          // eslint-disable-next-line no-console
          console.log(`Promise ${index} rejected with reason:`, result.reason);
        }
      });
    } catch (error) {
      console.error('Unexpected error:', error);
    }

    checkingPrerequisites = false;
  };

  $: txDestChainName = getChainName(Number(tx.destChainId));

  $: correctChain = Number(tx.destChainId) === $connectedSourceChain.id;

  $: successFullPreChecks = correctChain && hasEnoughEth && hasEnoughQuota;

  $: if (!checkingPrerequisites && successFullPreChecks && $account) {
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
  $: hasEnoughQuota = false;
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
      {#if isL2Chain(Number(tx.destChainId))}
        <div class="f-between-center">
          <span class="text-secondary-content">{$t('transactions.claim.steps.pre_check.quota_check')}</span>
          {#if checkingPrerequisites}
            <Spinner />
          {:else if hasEnoughQuota}
            <Icon type="check-circle" fillClass="fill-positive-sentiment" />
          {:else}
            <Icon type="x-close-circle" fillClass="fill-negative-sentiment" />
          {/if}
        </div>
      {/if}
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
