<script lang="ts">
  import { noop } from 'svelte/internal';
  import { t } from 'svelte-i18n';

  import { Icon } from '$components/Icon';
  import type { Token } from '$libs/token';

  import { symbolToIconMap } from './symbolToIconMap';

  export let id: string;
  export let menuOpen = false;
  export let tokens: Token[] = [];
  export let value: Maybe<Token> = null;
  export let selectToken: (token: Token) => void = noop;
  export let closeMenu: () => void = noop;
</script>

<!-- Mobile view -->
<dialog {id} class="modal modal-bottom" class:modal-open={menuOpen}>
  <div class="modal-box relative px-6 py-[35px] bg-neutral-background">
    <button class="absolute right-6 top-[35px]" on:click={closeMenu}>
      <Icon type="x-close" fillClass="fill-primary-icon" size={24} />
    </button>

    <h3 class="title-body-bold mb-7">{$t('token_dropdown.label')}</h3>

    <ul role="listbox" class="menu p-0 bg-neutral-background">
      {#each tokens as token (token.symbol)}
        {@const selected = token === value}
        <!-- svelte-ignore a11y-click-events-have-key-events -->
        <li
          role="option"
          tabindex="0"
          aria-selected={selected}
          class="rounded-[10px]"
          class:bg-tertiary-interactive-accent={selected}
          on:click={() => selectToken(token)}>
          <div class="p-4">
            <i role="img" aria-label={token.name}>
              <svelte:component this={symbolToIconMap[token.symbol]} />
            </i>
            <span class="body-bold">{token.symbol}</span>
          </div>
        </li>
      {/each}
    </ul>
  </div>
</dialog>
