<script lang="ts">
  import { fly } from 'svelte/transition';
  import { zeroAddress } from 'viem';

  import { ConnectButton } from '$components/ConnectButton';
  import { Button } from '$components/core/Button';
  import { ThemeButton } from '$components/ThemeButton';
  import { classNames } from '$lib/util/classNames';

  export let open = false;
  export let address = zeroAddress;
  export let isConnected = false;
  const buttonClasses = classNames();
</script>

{#if open}
  <div
    transition:fly
    class={classNames(
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
    )}>
    <div class="my-2">
      <ConnectButton connected={isConnected} />
    </div>

    <Button on:click={() => (open = false)} href="/mint" type="mobile" class={buttonClasses}>Mint</Button>
    <Button on:click={() => (open = false)} href="/collection" type="mobile" class={buttonClasses}>Collection</Button>

    {#if address !== zeroAddress}
      <Button
        on:click={() => (open = false)}
        href={`/collection/${address.toLowerCase()}`}
        type="mobile"
        class={buttonClasses}>
        Your taikoons</Button>
    {/if}

    <div
      class={classNames(
        'absolute',
        'bottom-8',
        'px-4',
        'w-full',
        'flex',
        'flex-row',
        'items-center',
        'justify-between',
      )}>
      <ThemeButton size="lg" />

      <div class="font-sans text-base text-content-tertiary">© 2024 Taiko Labs</div>
    </div>
  </div>
{/if}
