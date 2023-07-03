<script lang="ts" context="module">
  export const drawerToggleId = 'side-drawer-toggle';
</script>

<script lang="ts">
  import { t } from 'svelte-i18n';

  import { page } from '$app/stores';
  import { PUBLIC_GUIDE_URL, PUBLIC_L2_EXPLORER_URL } from '$env/static/public';

  import { Icon } from '../Icon';
  import { LinkButton } from '../LinkButton';
  import { LogoWithText } from '../Logo';

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
</script>

<div class="drawer md:drawer-open overflow-hidden">
  <input id={drawerToggleId} type="checkbox" class="drawer-toggle" bind:this={drawerToggleElem} />

  <div class="drawer-content">
    <slot />
  </div>

  <div class="drawer-side h-full">
    <label for={drawerToggleId} class="drawer-overlay" />

    <!--
      Slow transitions can be pretty annoying after a while.
      Let's reduce it to 100ms for a better experience.
    -->
    <div class="w-h-full !duration-100">
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

        <ul class="menu p-0 md:pt-10 space-y-2" on:click={closeDrawer} on:keydown={onMenuKeydown}>
          <li>
            <LinkButton active={isBridgePage}>
              <Icon type="bridge" fillClass="fill-white" />
              <span>{$t('nav.bridge')}</span>
            </LinkButton>
          </li>
          <li>
            <LinkButton href="/faucet" active={isFaucetPage}>
              <Icon type="faucet" />
              <span>{$t('nav.faucet')}</span>
            </LinkButton>
          </li>
          <li>
            <LinkButton href="/activities" active={isActivitiesPage}>
              <Icon type="activities" />
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
      </aside>
    </div>
  </div>
</div>
