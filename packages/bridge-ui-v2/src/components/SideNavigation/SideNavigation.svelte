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

  $: isBridgePage = $page.route.id === '/';
  $: isFaucetPage = $page.route.id === '/faucet';
  $: isActivitiesPage = $page.route.id === '/activities';
</script>

<div class="drawer md:drawer-open">
  <input id={drawerToggleId} type="checkbox" class="drawer-toggle" />

  <div class="drawer-content">
    <slot />
  </div>

  <div class="drawer-side h-full z-50 bg-primary-background">
    <label for={drawerToggleId} class="drawer-overlay bg-overlay-background" />

    <aside
      class="
      p-2 
      w-full
      h-full
      md:px-4 
      md:py-8 
      md:w-[226px] 
      md:border-r 
      md:border-r-divider-border">
      <a href="/" class="hidden md:inline-block">
        <LogoWithText />
      </a>

      <ul class="menu md:pt-10 space-y-2">
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
