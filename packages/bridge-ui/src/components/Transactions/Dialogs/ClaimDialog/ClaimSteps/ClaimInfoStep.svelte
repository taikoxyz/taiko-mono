<script lang="ts">
  import { getBalance, switchChain } from '@wagmi/core';
  import { type Address, parseEther } from 'viem';

  import { ActionButton } from '$components/Button';
  import { Icon } from '$components/Icon';
  import Spinner from '$components/Spinner/Spinner.svelte';
  import { claimConfig } from '$config';
  import type { BridgeTransaction } from '$libs/bridge';
  import { getChainName } from '$libs/chain';
  import { InsufficientBalanceError } from '$libs/error';
  import { config } from '$libs/wagmi';
  import { account } from '$stores/account';
  import { connectedSourceChain, switchingNetwork } from '$stores/network';
  export let tx: BridgeTransaction;

  export let canContinue = false;

  $: txDestChainName = getChainName(Number(tx.destChainId));

  $: correctChain = Number(tx.destChainId) === $connectedSourceChain.id;

  $: if (correctChain) {
    canContinue = true;
  } else {
    canContinue = false;
  }

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

  $: $account && tx.destChainId, checkEnoughBalance($account.address, Number(tx.destChainId));

  let checking: boolean;

  const checkEnoughBalance = async (address: Maybe<Address>, chainId: number) => {
    if (!address) {
      return false;
    }
    checking = true;

    const balance = await getBalance(config, { address, chainId });

    if (balance.value < parseEther(String(claimConfig.minimumEthToClaim))) {
      hasEnoughEth = false;
      checking = false;
      throw new InsufficientBalanceError('user has insufficient balance');
    }
    hasEnoughEth = true;
    checking = false;
  };

  $: hasEnoughEth = false;
</script>

<div class="container mx-auto inline-block align-middle space-y-[25px] w-full mt-[20px]">
  <div class="flex justify-between mb-2 items-center">
    <div class="font-bold text-primary-content">Prerequisites</div>
  </div>
  <div>
    <div class="f-between-center">
      <div>Connected to the correct chain:</div>
      {#if checking}
        <Spinner />
      {:else if correctChain}
        <Icon type="check-circle" fillClass="fill-positive-sentiment" />
      {:else}
        <Icon type="x-close-circle" fillClass="fill-negative-sentiment" />
      {/if}
    </div>
    <div class="f-between-center">
      <div>Enough funds to claim</div>
      {#if checking}
        <Spinner />
      {:else if hasEnoughEth}
        <Icon type="check-circle" fillClass="fill-positive-sentiment" />
      {:else}
        <Icon type="x-close-circle" fillClass="fill-negative-sentiment" />
      {/if}
    </div>
    <div class="h-sep" />
    {#if correctChain}
      You can continue with the claim process!
    {:else if tx.srcChainId && tx.destChainId && $connectedSourceChain.id}
      <div class="f-col space-y-[16px]">
        <div>
          This transaction is bridging to <span class="font-bold text-primary">{txDestChainName}</span> You need to be connected
          to this chain
        </div>

        <ActionButton
          onPopup
          priority="primary"
          disabled={$switchingNetwork}
          loading={$switchingNetwork}
          on:click={() => {
            switchChains();
          }}>Switch to {txDestChainName}</ActionButton>
      </div>
    {/if}
  </div>
</div>
