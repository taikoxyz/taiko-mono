<script lang="ts">
  import { BigNumber, type Signer, ethers } from 'ethers';
  import type { Token } from '../../domain/token';
  import type { Chain } from '../../domain/chain';
  import { isERC20 } from '../../token/tokens';
  import { fromChain } from '../../store/chain';
  import { token } from '../../store/token';
  import { signer } from '../../store/signer';
  import Button from '../Button.svelte';
  import Loading from '../Loading.svelte';
  import { ArrowRight } from 'svelte-heros-v2';

  export let requiresAllowance = false;
  export let computingAllowance = false;

  export let tokenBalance: string = '';
  export let computingTokenBalance = false;

  export let actionDisabled = false;

  export let amountEntered = false;

  export let approve: () => Promise<void>;
  export let bridge: () => Promise<void>;

  let approving = false;
  let bridging = false;

  function hasBalance(token: Token, tokenBalance: string) {
    return (
      tokenBalance &&
      ethers.utils
        .parseUnits(tokenBalance, token.decimals)
        .gt(BigNumber.from(0))
    );
  }

  function shouldShowSteps(
    computingTokenBalance: boolean,
    fromChain: Chain,
    token: Token,
    signer: Signer,
    tokenBalance: string,
  ) {
    return (
      !computingTokenBalance &&
      fromChain && // chain selected?
      signer && // wallet connected?
      isERC20(token) &&
      hasBalance(token, tokenBalance)
    );
  }

  function clickApprove() {
    approving = true;
    approve().finally(() => {
      approving = false;
    });
  }

  function clickBridge() {
    bridging = true;
    bridge().finally(() => {
      bridging = false;
    });
  }

  $: showSteps = shouldShowSteps(
    computingTokenBalance,
    $fromChain,
    $token,
    $signer,
    tokenBalance,
  );

  $: loading = approving || bridging;
</script>

{#if showSteps}
  <div class="flex space-x-4 items-center">
    {#if loading}
      <Button type="accent" class="flex-1" disabled={true}>
        {#if approving}
          <Loading text="Approving…" />
        {:else}
          ✓ Approved
        {/if}
      </Button>
      <ArrowRight />
      <Button type="accent" class="flex-1" disabled={true}>
        {#if bridging}
          <Loading text="Bridging…" />
        {:else}
          Bridge
        {/if}
      </Button>
    {:else}
      <Button
        type="accent"
        class="flex-1"
        on:click={clickApprove}
        disabled={!requiresAllowance || actionDisabled}>
        {requiresAllowance
          ? 'Approval required'
          : !computingAllowance && amountEntered
          ? '✓ Approved'
          : 'Approve'}
      </Button>
      <ArrowRight />
      <Button
        type="accent"
        class="flex-1"
        on:click={clickBridge}
        disabled={requiresAllowance || actionDisabled}>
        {requiresAllowance
          ? 'Bridge'
          : !computingAllowance && amountEntered
          ? 'Ready to bridge'
          : 'Bridge'}
      </Button>
    {/if}
  </div>
{:else if bridging}
  <Button type="accent" class="w-full" disabled={true}>
    <Loading text="Bridging…" />
  </Button>
{:else}
  <Button
    type="accent"
    class="w-full"
    on:click={clickBridge}
    disabled={actionDisabled}>
    Bridge
  </Button>
{/if}
