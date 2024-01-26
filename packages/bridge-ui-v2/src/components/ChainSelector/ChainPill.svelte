<script lang="ts">
  import type { Chain, GetNetworkResult } from '@wagmi/core';
  import { t } from 'svelte-i18n';

  import { chainConfig } from '$chainConfig';
  import { chains } from '$libs/chain';
  import { classNames } from '$libs/util/classNames';
  import { truncateString } from '$libs/util/truncateString';
  import { uid } from '$libs/util/uid';

  export let value: Maybe<GetNetworkResult['chain']> = null;
  export let label = '';
  // export let switchWallet = false;
  export let readOnly = false;
  export let validOptions: Maybe<Chain[]> = chains;
  export let highlight = false;

  $: highlightBorder = highlight && validOptions?.length ? 'border-2 border-primary' : '';

  let classes = classNames('ChainSelector', $$props.class);

  let buttonClasses = `body-regular bg-neutral-background px-2 py-[6px] !rounded-[10px] ${
    readOnly ? '' : 'dark:hover:bg-tertiary-interactive-hover'
  } flex justify-start content-center ${$$props.class}`;

  let iconSize = 'min-w-5 max-w-5 min-h-5 max-h-5';

  let buttonId = `button-${uid()}`;
  let dialogId = `dialog-${uid()}`;
  let modalOpen = false;

  function closeModal() {
    modalOpen = false;
  }
</script>

<div class={classes}>
  <div class="f-items-center space-x-[10px]">
    {#if label}
      <label class="text-secondary-content body-regular" for={buttonId}>{label}:</label>
    {/if}
    <button
      id={buttonId}
      type="button"
      disabled={readOnly}
      aria-haspopup="dialog"
      aria-controls={dialogId}
      aria-expanded={modalOpen}
      class="{buttonClasses}{highlightBorder}"
      on:click={closeModal}>
      <div class="f-items-center space-x-2 w-full">
        {#if !value}
          <span>{$t('chain_selector.placeholder')}</span>
        {/if}
        {#if value}
          {@const icon = chainConfig[Number(value.id)]?.icon || 'Unknown Chain'}
          <i role="img" aria-label={value.name}>
            <img src={icon} alt="chain-logo" class="rounded-full {iconSize}" />
          </i>
          <span>{truncateString(value.name, 8)}</span>
        {/if}
      </div>
    </button>
  </div>
</div>
