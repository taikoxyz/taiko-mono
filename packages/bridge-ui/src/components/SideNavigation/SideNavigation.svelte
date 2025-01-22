<script lang="ts" context="module">
  export const drawerToggleId = 'side-drawer-toggle';
</script>

<script lang="ts">
  import { t } from 'svelte-i18n';

  import { page } from '$app/stores';
  import { chainConfig } from '$chainConfig';
  import BridgeTabs from '$components/Bridge/BridgeTabs.svelte';
  import { Icon } from '$components/Icon';
  import { LinkButton } from '$components/LinkButton';
  import { ThemeButton } from '$components/ThemeButton';
  import {
    PUBLIC_DEFAULT_EXPLORER,
    PUBLIC_DEFAULT_SWAP_URL,
    PUBLIC_GUIDE_URL,
    PUBLIC_TESTNET_NAME,
  } from '$env/static/public';
  import { connectedSourceChain } from '$stores/network';

  let testnetName = PUBLIC_TESTNET_NAME || '';
  let drawerToggleElem: HTMLInputElement;

  export let sideBarOpen: boolean;

  function closeDrawer() {
    if (!drawerToggleElem) return;
    drawerToggleElem.checked = false;
    sideBarOpen = false;
  }

  function onMenuKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape' || event.key === 'Enter') {
      closeDrawer();
    }
  }

  function getIconFillClass(active: boolean) {
    return active ? 'fill-white' : 'fill-primary-icon';
  }

  $: isBridgePage = $page.route.id === '/' || $page.route.id === '/nft';
  $: isFaucetPage = $page.route.id === '/faucet';
  $: isTransactionsPage = $page.route.id === '/transactions';
</script>

<div class=" drawer lg:drawer-open">
  <input id={drawerToggleId} type="checkbox" class="drawer-toggle" bind:this={drawerToggleElem} />
  <div class="drawer-content relative f-col w-full">
    <slot />
  </div>

  <div class="drawer-side z-20 pt-[81px] lg:pt-[20px] h-full">
    <label for={drawerToggleId} class="drawer-overlay" />

    <!--
      Slow transitions can be pretty annoying after a while.
      Let's reduce it to 100ms for a better experience.
    -->
    <div class="w-full !duration-100">
      <aside
        class="
        h-full
        px-[20px]
        lg:mt-0
        lg:px-4
        lg:w-[226px]
      ">
        <div class="hidden lg:inline-block"></div>
        <div role="button" tabindex="0" on:click={closeDrawer} on:keypress={closeDrawer}>
          <BridgeTabs class="lg:hidden flex flex-1 mb-[40px] mt-[20px]" on:click={closeDrawer} />
        </div>
        <div role="button" tabindex="0" on:click={closeDrawer} on:keydown={onMenuKeydown}>
          <ul class="menu p-0 space-y-2">
            <li>
              <LinkButton active={isBridgePage}>
                <Icon type="bridge" fillClass={getIconFillClass(isBridgePage)} />
                <span>{$t('nav.bridge')}</span>
              </LinkButton>
            </li>
            {#if testnetName !== ''}
              <li>
                <LinkButton href="/faucet" active={isFaucetPage}>
                  <Icon type="faucet" fillClass={getIconFillClass(isFaucetPage)} />
                  <span>{$t('nav.faucet')}</span>
                </LinkButton>
              </li>
            {/if}
            <li>
              <LinkButton href="/transactions" active={isTransactionsPage} on:click={closeDrawer}>
                <Icon type="transactions" fillClass={getIconFillClass(isTransactionsPage)} />
                <span>{$t('nav.transactions')}</span>
              </LinkButton>
            </li>
            {#if PUBLIC_DEFAULT_SWAP_URL && PUBLIC_DEFAULT_SWAP_URL !== ''}
              <li class="border-t border-t-divider-border pt-2">
                <LinkButton href={PUBLIC_DEFAULT_SWAP_URL} external>
                  <Icon type="swap" />
                  <span>{$t('nav.swap')}</span>
                </LinkButton>
              </li>
            {/if}
            <li>
              <LinkButton
                href={$connectedSourceChain
                  ? chainConfig[$connectedSourceChain.id]?.blockExplorers?.default.url
                  : PUBLIC_DEFAULT_EXPLORER}
                external>
                <Icon type="explorer" />
                <span>{$t('nav.explorer')}</span>
              </LinkButton>
            </li>
            <li>
              <LinkButton href={PUBLIC_GUIDE_URL} external>
                <Icon type="guide" />
                <span>{$t('nav.guide')}</span>
              </LinkButton>
            </li>
          </ul>
        </div>
        <ul class="">
          <li>
            <div class="p-3 rounded-full flex lg:hidden justify-start content-center">
              <Icon type="settings" />
              <div class="flex justify-between w-full pl-[6px]">
                <span class="text-base">{$t('nav.theme')}</span>
                <ThemeButton mobile />
              </div>
            </div>
          </li>
        </ul>
      </aside>
    </div>
  </div>
</div>
