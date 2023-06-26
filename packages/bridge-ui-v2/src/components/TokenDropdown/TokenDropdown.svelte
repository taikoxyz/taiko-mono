<script lang="ts">
  import type { ComponentType } from 'svelte';
  import { t } from 'svelte-i18n';

  import { BllIcon, EthIcon, HorseIcon, Icon } from '$components/Icon';

  export let tokens: Token[] = [];
  export let onSelectedTokenChange: (token: Token) => void;

  let symbolToIconMap: Record<string, ComponentType> = {
    ETH: EthIcon,
    BLL: BllIcon,
    HORSE: HorseIcon,
  };

  let selectedToken: Token;
</script>

<div class="dropdown" role="listbox">
  <button
    class="w-full flex justify-between items-center px-6 py-[14px] rounded-[10px] border border-primary-border hover:border-primary-border-hover">
    <div class="space-x-2">
      {#if !selectedToken}
        <span class="text-tertiary-content body-small-regular">{$t('bridge.select_token')}…</span>
      {/if}
      {#if selectedToken}
        <i>
          <svelte:component this={symbolToIconMap[selectedToken.symbol]} />
        </i>
        <span>{selectedToken.name}</span>
      {/if}
    </div>
    <Icon type="chevron-down" />
  </button>
  <ul class="menu dropdown-content" role="listbox">
    {#each tokens as token (token.symbol)}
      <li role="option" aria-selected={selectedToken === token}>
        <i />
        <span>{token.name}</span>
      </li>
    {/each}
  </ul>
</div>
