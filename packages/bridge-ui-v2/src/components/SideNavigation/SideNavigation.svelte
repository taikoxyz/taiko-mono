<script context="module">
  export const drawerToogleId = 'side-drawer-toggle';
</script>

<script lang="ts">
  import { PUBLIC_GUIDE_URL, PUBLIC_L2_EXPLORER_URL } from '$env/static/public';

  import Icon from '../Icon';
  import LinkButton from '../LinkButton';
  import { LogoWithText } from '../Logo';
</script>

<div class="drawer md:drawer-open">
  <input id={drawerToogleId} type="checkbox" class="drawer-toggle" />

  <div class="drawer-content">
    <slot />
  </div>

  <div class="drawer-side z-1 bg-primary-background">
    <label for={drawerToogleId} class="drawer-overlay bg-overlay-background" />

    <aside class="w-[226px] md:px-4 md:py-8 md:border-r md:border-r-grey-600 h-full">
      <a href="/" class="hidden md:block">
        <LogoWithText />
      </a>
      <ul class="menu md:pt-10 space-y-2">
        <li>
          <LinkButton active>
            <Icon type="bridge" fillClass="fill-white" />
            <span>Bridge</span>
          </LinkButton>
        </li>
        <li>
          <LinkButton href="/faucet">
            <Icon type="faucet" />
            <span>Faucet</span>
          </LinkButton>
        </li>
        <li>
          <LinkButton href="/activities">
            <Icon type="activities" />
            <span>Activities</span>
          </LinkButton>
        </li>
        <li>
          <LinkButton href={PUBLIC_L2_EXPLORER_URL} target="_blank">
            <Icon type="explorer" />
            <span>Exploreer</span>
          </LinkButton>
        </li>
        <li>
          <LinkButton href={PUBLIC_GUIDE_URL} target="_blank">
            <Icon type="guide" />
            <span>Guide</span>
          </LinkButton>
        </li>
      </ul>
    </aside>
  </div>
</div>
