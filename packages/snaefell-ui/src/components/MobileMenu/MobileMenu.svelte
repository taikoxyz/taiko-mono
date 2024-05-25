<script lang="ts">
  import { fly } from 'svelte/transition';
  import { zeroAddress } from 'viem';

  import { ConnectButton } from '$components/ConnectButton';
  import { Button } from '$components/core/Button';
  import { ThemeButton } from '$components/ThemeButton';
  import { classNames } from '$lib/util/classNames';

  import type { IAddress } from '../../types';

  export let open = false;
  export let address = zeroAddress as IAddress;
  export let isConnected = false;

  const wrapperClasses = classNames(
    'fixed',
    'top-0',
    'left-0',
    'bg-background-primary',
    'w-full',
    'h-full',
    'pt-32',
    'px-4',
    'flex',
    'flex-col',
    'items-start',
    'justify-start',
    'gap-4',
  );

  const buttonsWrapperClasses = classNames(
    'absolute',
    'bottom-8',
    'px-4',
    'w-full',
    'flex',
    'flex-row',
    'items-center',
    'justify-between',
  );
</script>

{#if open}
  <div transition:fly class={wrapperClasses}>
    <div class="my-2">
      <ConnectButton connected={isConnected} />
    </div>

    <Button on:click={() => (open = false)} href="/mint" type="mobile">Mint</Button>
    <Button on:click={() => (open = false)} href="/collection" type="mobile">Collection</Button>

    {#if address !== zeroAddress}
      <Button on:click={() => (open = false)} href={`/collection/${address.toLowerCase()}`} type="mobile">
        Your taikoons</Button>
    {/if}

    <div class={buttonsWrapperClasses}>
      <ThemeButton size="lg" />

      <div class="font-sans text-base text-content-tertiary pr-6">© 2024 Taiko Labs</div>
    </div>
  </div>
{/if}
