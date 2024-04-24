<script lang="ts">
  import { t } from 'svelte-i18n';
  import type { Chain } from 'viem';

  import { chainConfig } from '$chainConfig';
  import ChainsDialog from '$components/ChainSelectors/SelectorDialogs/ChainsDialog.svelte';
  import ChainsDropdown from '$components/ChainSelectors/SelectorDialogs/ChainsDropdown.svelte';
  import { DesktopOrLarger } from '$components/DesktopOrLarger';
  import { classNames } from '$libs/util/classNames';
  import { truncateString } from '$libs/util/truncateString';
  import { uid } from '$libs/util/uid';
  import { account } from '$stores';

  export let value: Maybe<Chain> | null = null;
  export let label = '';
  export let readOnly = false;
  export let selectChain: (event: CustomEvent<{ chain: Chain; switchWallet: boolean }>) => Promise<void>;

  export let switchWallet = false;

  let isDesktopOrLarger = false;

  let classes = classNames('ChainPill relative', $$props.class);

  let buttonClasses = `f-row body-regular bg-neutral-background px-2 py-[6px] !rounded-[10px] dark:hover:bg-primary-secondary-hover flex justify-start content-center ${$$props.class}`;

  let iconSize = 'min-w-5 max-w-5 min-h-5 max-h-5';

  let buttonId = `button-${uid()}`;
  let dialogId = `dialog-${uid()}`;
  let modalOpen = false;

  const handlePillClick = () => {
    if (switchWallet) {
      modalOpen = true;
    }
  };

  $: disabled = !$account || !$account.isConnected || readOnly;
</script>

<div class={classes}>
  <div class="f-items-center space-x-[10px]">
    {#if label}
      <label class="text-secondary-content body-regular" for={buttonId}>{label}:</label>
    {/if}
    <button
      id={buttonId}
      type="button"
      {disabled}
      aria-haspopup="dialog"
      aria-controls={dialogId}
      aria-expanded={modalOpen}
      class={buttonClasses}
      on:click={handlePillClick}>
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
  {#if isDesktopOrLarger}
    <ChainsDropdown class="rounded-[20px]" on:change={selectChain} bind:isOpen={modalOpen} bind:value switchWallet />
  {:else}
    <ChainsDialog on:change={selectChain} bind:isOpen={modalOpen} bind:value switchWallet />
  {/if}
</div>

<DesktopOrLarger bind:is={isDesktopOrLarger} />
