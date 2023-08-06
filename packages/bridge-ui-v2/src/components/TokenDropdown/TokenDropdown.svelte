<script lang="ts">
  import { type Address,getNetwork } from '@wagmi/core';
  import { onDestroy } from 'svelte';
  import { t } from 'svelte-i18n';

  import { DesktopOrLarger } from '$components/DesktopOrLarger';
  import { Icon } from '$components/Icon';
  import Erc20 from '$components/Icon/ERC20.svelte';
  import { tokenService } from '$libs/storage/services';
  import type { Token } from '$libs/token';
  import { getCrossChainAddress } from '$libs/token/getCrossChainAddress';
  import { uid } from '$libs/util/uid';
  import { account } from '$stores/account';

  import { destNetwork } from '../Bridge/state';
  import DialogView from './DialogView.svelte';
  import DropdownView from './DropdownView.svelte';
  import { symbolToIconMap } from './symbolToIconMap';

  export let tokens: Token[] = [];
  export let value: Maybe<Token> = null;

  let id = `menu-${uid()}`;
  let menuOpen = false;

  // This will control which view to render depending on the screensize.
  // Since markup will differ, and there is logic running when interacting
  // with this component, it makes more sense to not render the view that's
  // not being used, doing this with JS instead of CSS media queries
  let isDesktopOrLarger: boolean;

  const closeMenu = () => (menuOpen = false);

  const openMenu = () => {
    menuOpen = true;
  };

  const selectToken = async (token: Token) => {
    const { chain } = getNetwork();
    const destChain = $destNetwork;

    if (!chain || !destChain) throw new Error('Chain not found');

    // if it is an imported Token, chances are we do not yet have the bridged address
    // for the destination chain, so we need to fetch it
    if (token.imported) {
      const bridgedAddress = await getCrossChainAddress({
        token,
        srcChainId: chain.id,
        destChainId: destChain.id,
      });
      token.addresses[destChain.id] = bridgedAddress as Address;

      tokenService.updateToken(token, $account?.address as Address);
    }
    value = token;

    closeMenu();
  };

  onDestroy(() => closeMenu());
</script>

<DesktopOrLarger bind:is={isDesktopOrLarger} />

<div class="relative">
  <button
    aria-haspopup="listbox"
    aria-controls={id}
    aria-expanded={menuOpen}
    class="f-between-center w-full px-6 py-[14px] input-box"
    on:click={openMenu}
    on:focus={openMenu}>
    <div class="space-x-2">
      {#if !value}
        <span class="title-subsection-bold text-tertiary-content leading-8">{$t('token_dropdown.label')}</span>
      {/if}
      {#if value}
        <div class="flex space-x-2 items-center">
          {#if symbolToIconMap[value.symbol]}
            <i role="img" aria-label={value.name}>
              <svelte:component this={symbolToIconMap[value.symbol]} />
            </i>
          {:else}
            <i role="img" aria-label={value.symbol}>
              <Erc20 />
            </i>
          {/if}
          <span class="title-subsection-bold">{value.symbol}</span>
        </div>
      {/if}
    </div>
    <Icon type="chevron-down" />
  </button>

  {#if isDesktopOrLarger}
    <DropdownView {id} {menuOpen} {tokens} {value} {selectToken} />
  {:else}
    <DialogView {id} {menuOpen} {tokens} {value} {selectToken} {closeMenu} on:closemenu={closeMenu} />
  {/if}
</div>
