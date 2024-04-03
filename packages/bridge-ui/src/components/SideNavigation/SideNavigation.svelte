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
  import { LogoWithText } from '$components/Logo';
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

  function closeDrawer() {
    drawerToggleElem.checked = false;
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

  $: hasTestnetName = testnetName !== '';
</script>

<div class="drawer md:drawer-open">
  <input id={drawerToggleId} type="checkbox" class="drawer-toggle" bind:this={drawerToggleElem} />

  <div class="drawer-content relative f-col w-full">
    <slot />
  </div>

  <!-- Side drawer's z-index (20) must be greater than content's header (10)-->
  <div class="drawer-side z-20">
    <label for={drawerToggleId} class="drawer-overlay" />

    <!--
      Slow transitions can be pretty annoying after a while.
      Let's reduce it to 100ms for a better experience.
    -->
    <div class="w-h-full !duration-100">
      <header class="flex justify-between py-[20px] px-[16px] h-[76px] md:hidden border-b border-b-divider-border">
        <div class="inline-block">
          <a href="/" class="f-row gap-2">
            <LogoWithText textFillClass="fill-primary-content" width={77} />
            {#if hasTestnetName}
              <span class="text-xs">{testnetName}</span>
            {/if}
          </a>
        </div>
        <button on:click={closeDrawer} class="h-9">
          <Icon type="x-close" fillClass="fill-primary-icon" size={24} />
        </button>
      </header>

      <aside
        class="
        h-full
        px-[20px]
        md:mt-0
        md:px-4
        md:py-8
        md:w-[226px]
      ">
        <div class="hidden md:inline-block">
          <a href="/" class="f-row gap-2">
            <LogoWithText textFillClass="fill-primary-content" />
            {#if hasTestnetName}
              <span class="text-sm">{testnetName}</span>
            {/if}
          </a>
        </div>

        <div role="button" tabindex="0" on:click={closeDrawer} on:keypress={closeDrawer}>
          <BridgeTabs class="md:hidden flex flex-1 mb-[40px] mt-[20px]" on:click={closeDrawer} />
        </div>
        <div role="button" tabindex="0" on:click={closeDrawer} on:keydown={onMenuKeydown}>
          <ul class="menu p-0 md:pt-10 space-y-2">
            <li>
              <LinkButton active={isBridgePage}>
                <Icon type="bridge" fillClass={getIconFillClass(isBridgePage)} />
                <span>{$t('nav.bridge')}</span>
              </LinkButton>
            </li>
            <li>
              <LinkButton href="/faucet" active={isFaucetPage}>
                <Icon type="faucet" fillClass={getIconFillClass(isFaucetPage)} />
                <span>{$t('nav.faucet')}</span>
              </LinkButton>
            </li>
            <li>
              <LinkButton href="/transactions" active={isTransactionsPage}>
                <Icon type="transactions" fillClass={getIconFillClass(isTransactionsPage)} />
                <span>{$t('nav.transactions')}</span>
              </LinkButton>
            </li>
            <li class="border-t border-t-divider-border pt-2">
              <LinkButton href={PUBLIC_DEFAULT_SWAP_URL} external>
                <Icon type="swap" />
                <span>{$t('nav.swap')}</span>
              </LinkButton>
            </li>
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
            <div class="p-3 rounded-full flex md:hidden justify-start content-center">
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
