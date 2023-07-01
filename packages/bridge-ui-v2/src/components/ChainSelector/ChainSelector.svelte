<script lang="ts">
  import type { ComponentType } from 'svelte';
  import { noop, onDestroy } from 'svelte/internal';
  import { t } from 'svelte-i18n';

  import { EthIcon, Icon, TaikoIcon } from '$components/Icon';
  import { PUBLIC_L1_CHAIN_ID, PUBLIC_L2_CHAIN_ID } from '$env/static/public';
  import { chains, type ExtendedChain } from '$libs/chain';
  import { uid } from '$libs/util/uid';

  export let label: string;
  export let onChange: (chain: ExtendedChain) => void = noop;

  let chainToIconMap: Record<string, ComponentType> = {
    [PUBLIC_L1_CHAIN_ID]: EthIcon,
    [PUBLIC_L2_CHAIN_ID]: TaikoIcon,
  };

  let buttonId = `button-${uid()}`;
  let dialogId = `dialog-${uid()}`;
  let selectedChain: ExtendedChain;
  let modalOpen = false;

  function closeModal() {
    modalOpen = false;
  }

  function openModal() {
    modalOpen = true;
  }

  function selectChain(chain: ExtendedChain) {
    selectedChain = chain;
    onChange?.(chain); // TODO: data binding? 🤔
    closeModal();
  }

  function onChainKeydown(event: KeyboardEvent, chain: ExtendedChain) {
    if (event.key === 'Enter') {
      selectChain(chain);
    }
  }

  onDestroy(closeModal);
</script>

<div class="ChainSelector">
  <div class="f-items-center space-x-[10px]">
    <label class="text-secondary-content body-regular" for={buttonId}>{label}:</label>
    <button
      id={buttonId}
      type="button"
      aria-haspopup="dialog"
      aria-controls={dialogId}
      aria-expanded={modalOpen}
      class="px-2 py-[6px] body-small-regular bg-neutral-background rounded-md min-w-[150px]"
      on:click={openModal}>
      <div class="f-items-center space-x-2">
        {#if !selectedChain}
          <span>{$t('chain_selector.placeholder')}…</span>
        {/if}
        {#if selectedChain}
          <i role="img" aria-label={selectedChain.name}>
            <svelte:component this={chainToIconMap[selectedChain.id]} size={20} />
          </i>
          <span>{selectedChain.name}</span>
        {/if}
      </div>
    </button>
  </div>

  <dialog id={dialogId} class="modal" class:modal-open={modalOpen}>
    <div class="modal-box relative px-6 py-[21px] bg-primary-base-background text-primary-base-content">
      <button class="absolute right-6 top-[21px]" on:click={closeModal}>
        <Icon type="x-close" fillClass="fill-secondary-icon" />
      </button>
      <h3 class="title-body-bold">{$t('chain_selector.placeholder')}</h3>
      <ul class="menu space-y-4">
        {#each chains as chain (chain.id)}
          <li
            role="menuitem"
            tabindex="0"
            on:click={() => selectChain(chain)}
            on:keydown={(event) => onChainKeydown(event, chain)}>
            <!-- TODO: agree on hover:bg color -->
            <div class="f-row justify-between hover:text-primary-base-content hover:bg-grey-10">
              <div class="f-items-center space-x-4">
                <i role="img" aria-label={chain.name}>
                  <svelte:component this={chainToIconMap[chain.id]} size={32} />
                </i>
                <span class="body-bold">{chain.name}</span>
              </div>
              <span class="body-regular">{chain.network}</span>
            </div>
          </li>
        {/each}
      </ul>
    </div>

    <div class="overlay-backdrop" />
  </dialog>
</div>
