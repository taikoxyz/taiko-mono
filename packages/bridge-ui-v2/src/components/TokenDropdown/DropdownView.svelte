<script lang="ts">
  import { noop } from 'svelte/internal';

  import { ClickMask } from '$components/ClickMask';
  import type { Token } from '$libs/token';
  import { classNames } from '$libs/util/classNames';

  import { symbolToIconMap } from './symbolToIconMap';

  export let id: string;
  export let menuOpen = false;
  export let tokens: Token[] = [];
  export let value: Maybe<Token> = null;
  export let selectToken: (token: Token) => void = noop;
  export let closeMenu: () => void = noop;

  $: menuClasses = classNames(
    'menu absolute right-0 w-[265px] p-3 mt-2 rounded-[10px] bg-neutral-background z-10',
    menuOpen ? 'visible opacity-100' : 'invisible opacity-0',
  );

  function getTokenKeydownHandler(token: Token) {
    return (event: KeyboardEvent) => {
      if (event.key === 'Enter') {
        selectToken(token);
      }
    };
  }
</script>

<!-- Desktop (or larger) view -->
<ul role="listbox" {id} class={menuClasses}>
  {#each tokens as token (token.symbol)}
    <li
      role="option"
      tabindex="0"
      aria-selected={token === value}
      on:click={() => selectToken(token)}
      on:keydown={getTokenKeydownHandler(token)}>
      <div class="p-4">
        <i role="img" aria-label={token.name}>
          <svelte:component this={symbolToIconMap[token.symbol]} />
        </i>
        <span class="body-bold">{token.symbol}</span>
      </div>
    </li>
  {/each}
</ul>

<ClickMask fn={closeMenu} active={menuOpen} />
