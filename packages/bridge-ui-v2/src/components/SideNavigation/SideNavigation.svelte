<script lang="ts" context="module">
  export const drawerToggleId = 'side-drawer-toggle';
</script>

<script lang="ts">
  import { t } from 'svelte-i18n';

  import { page } from '$app/stores';
  import { Icon } from '$components/Icon';
  import { LinkButton } from '$components/LinkButton';
  import { LogoWithText } from '$components/Logo';
  import { PUBLIC_GUIDE_URL, PUBLIC_L2_EXPLORER_URL } from '$env/static/public';

  let drawerToggleElem: HTMLInputElement;

  $: isBridgePage = $page.route.id === '/';
  $: isFaucetPage = $page.route.id === '/faucet';
  $: isActivitiesPage = $page.route.id === '/activities';

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
</script>

<div class="drawer md:drawer-open">
  <input id={drawerToggleId} type="checkbox" class="drawer-toggle" bind:this={drawerToggleElem} />

  <div class="drawer-content relative">
    <slot />
  </div>

  <!-- Side drawer's z-index (20) must be greater than content's header (10)-->
  <div class="drawer-side z-20">
    <label for={drawerToggleId} class="drawer-overlay" />

    <!--
      Slow transitions can be pretty annoying after a while.
      Let's reduce it to 100ms for a better experience.
    -->
    <div class="w-h-full bg-primary-background !duration-100">
      <header class="flex justify-end py-[20px] px-4 md:hidden">
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
        md:border-r
        md:border-r-divider-border">
        <a href="/" class="hidden md:inline-block">
          <LogoWithText />
        </a>

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
              <LinkButton href="/activities" active={isActivitiesPage}>
                <Icon type="activities" fillClass={getIconFillClass(isActivitiesPage)} />
                <span>{$t('nav.activities')}</span>
              </LinkButton>
            </li>
            <li>
              <LinkButton href={PUBLIC_L2_EXPLORER_URL} external>
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
      </aside>
    </div>
  </div>
</div>

<style>
  .drawer-content {
    /* No grid background by default */
    background-image: url(/bg/spotlights.svg), linear-gradient(180deg, rgb(11 16 27 / 70%) 0%, rgb(11 16 27 / 0%) 100%);
    background-size: cover, cover;
    background-blend-mode: lighten, multiply;
    background-attachment: fixed;
  }

  @media (min-width: 768px) {
    .drawer-content {
      /* Desktop of larger screens (md) have grid */
      /* TODO: Ask Jane if we have the right svgs here */
      background-image:
        url(/bg/grid.svg),
        url(/bg/spotlights.svg),
        /* grey-900/70 => grey-900/0 */ linear-gradient(180deg, rgb(11 16 27 / 70%) 0%, rgb(11 16 27 / 0%) 100%);
      background-size: cover, cover, cover;
      background-blend-mode: color-dodge, lighten, multiply;
    }
  }
</style>
