<script context="module">
  export const drawerToogleId = 'side-drawer-toggle';
</script>

<script lang="ts">
  import LinkButton from '../LinkButton';
  import Icon from '../Icon';
  import { LogoWithText } from '../Logo';

  // TODO: env vars
  let explorerUrl = 'https://explorer.internal.taiko.xyz/';
  let guideUrl = 'https://taiko.xyz/docs/guides/use-the-bridge';
</script>

<div class="drawer md:drawer-open">
  <input id={drawerToogleId} type="checkbox" class="drawer-toggle" />

  <div class="drawer-content">
    <slot />
  </div>

  <div class="drawer-side z-1 bg-primary-background md:border-r md:border-r-grey-600">
    <label for={drawerToogleId} class="drawer-overlay bg-overlay-background" />

    <aside class="md:w-[226px] md:px-4 md:py-8 h-full">
      <a href="/">
        <LogoWithText />
      </a>
      <ul class="menu pt-10 space-y-2">
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
          <LinkButton href={explorerUrl} target="_blank">
            <Icon type="explorer" />
            <span>Exploreer</span>
          </LinkButton>
        </li>
        <li>
          <LinkButton href={guideUrl} target="_blank">
            <Icon type="guide" />
            <span>Guide</span>
          </LinkButton>
        </li>
      </ul>
    </aside>
  </div>
</div>
