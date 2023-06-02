<script lang="ts">
  import { BigNumber, ethers, type Signer } from 'ethers';
  import { ArrowRight } from 'svelte-heros-v2';

  import type { Chain } from '../../domain/chain';
  import type { Token } from '../../domain/token';
  import { srcChain } from '../../store/chain';
  import { signer } from '../../store/signer';
  import { isERC20 } from '../../token/tokens';
  import Button from '../Button.svelte';
  import Loading from '../Loading.svelte';

  export let token: Token;

  export let requiresAllowance = false;
  export let computingAllowance = false;

  export let tokenBalance: string = '';
  export let computingTokenBalance = false;

  export let actionDisabled = false;

  export let amountEntered = false;

  export let approve: (token: Token) => Promise<void>;
  export let bridge: (token: Token) => Promise<void>;

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
    token: Token,
    signer: Signer,
    srcChain: Chain,
    tokenBalance: string,
    computingTokenBalance: boolean,
  ) {
    return (
      !computingTokenBalance &&
      srcChain && // chain selected?
      signer && // wallet connected?
      token && // token selected?
      isERC20(token) &&
      hasBalance(token, tokenBalance)
    );
  }

  function clickApprove() {
    approving = true;
    approve(token).finally(() => {
      approving = false;
    });
  }

  function clickBridge() {
    bridging = true;
    bridge(token).finally(() => {
      bridging = false;
    });
  }

  $: showSteps = shouldShowSteps(
    token,
    $signer,
    $srcChain,
    tokenBalance,
    computingTokenBalance,
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
          ? 'Approve token'
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
        Bridge
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
