<script lang="ts">
  import LinkButton from '../LinkButton';
  import Icon from '../Icon';
  import { LogoWithText } from '../Logo';

  let explorerUrl = 'https://explorer.internal.taiko.xyz/';
  let guideUrl = 'https://taiko.xyz/docs/guides/use-the-bridge';
</script>

<div class="SideNavigation drawer md:drawer-open">
  <input id="side-drawer-toggle" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content">
    <slot />
  </div>
  <div class="drawer-side px-4 py-8 border-r border-r-grey-600">
    <label for="side-drawer-toggle" class="drawer-overlay" />
    <aside class="md:w-[226px]">
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
