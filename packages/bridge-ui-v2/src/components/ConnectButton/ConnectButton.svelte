<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { Button } from '$components/Button';
  import { Icon } from '$components/Icon';
  import { web3modal } from '$libs/connect';
  import { noop } from '$libs/util/noop';
  export let connected = false;

  let web3modalOpen = false;
  let unsubscribeWeb3Modal = noop;

  function connectWallet() {
    if (web3modalOpen) return;
    web3modal.open();
  }

  function onWeb3Modal(state: { open: boolean }) {
    web3modalOpen = state.open;
  }

  onMount(() => {
    unsubscribeWeb3Modal = web3modal.subscribeState(onWeb3Modal);
  });

  onDestroy(unsubscribeWeb3Modal);
</script>

{#if connected}
  <w3m-button />
{:else}
  <Button class="px-[20px] py-2 rounded-full w-[215px]" type="neutral" loading={web3modalOpen} on:click={connectWallet}>
    <span class="body-regular f-items-center space-x-2">
      {#if web3modalOpen}
        <span>{$t('wallet.status.connecting')}</span>
      {:else}
        <Icon type="user-circle" class="md-show-block" />
        <span>{$t('wallet.connect')}</span>
      {/if}
    </span>
  </Button>
{/if}
