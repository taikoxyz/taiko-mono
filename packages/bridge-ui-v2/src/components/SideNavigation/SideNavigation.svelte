<script lang="ts">
  import LinkButton from '../LinkButton';
  import BridgeIcon from '../icons/bridge.svelte';

  let explorerUrl = 'https://explorer.internal.taiko.xyz/';
  let guideUrl = 'https://taiko.xyz/docs/guides/use-the-bridge';
</script>

<div class="SideNavigation drawer md:drawer-open">
  <input id="side-drawer-toggle" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content">
    <slot />
  </div>
  <div class="drawer-side">
    <label for="side-drawer-toggle" class="drawer-overlay" />
    <aside class="md:w-[226px]">
      <a href="/">
        <img src="/taiko-h-wht.svg" alt="Taiko logo" class="w-20 md:w-[125px]" />
      </a>
      <ul class="menu">
        <li>
          <LinkButton active>
            <BridgeIcon />
            <span>Bridge</span>
          </LinkButton>
        </li>
        <li>
          <LinkButton href="/faucet">
            <span>Faucet</span>
          </LinkButton>
        </li>
        <li>
          <LinkButton href="/activities">
            <span>Activities</span>
          </LinkButton>
        </li>
        <li>
          <LinkButton href={explorerUrl} target="_blank">
            <span>Exploreer</span>
          </LinkButton>
        </li>
        <li>
          <LinkButton href={guideUrl} target="_blank">
            <span>Guide</span>
          </LinkButton>
        </li>
      </ul>
    </aside>
  </div>
</div>

<style lang="postcss">
  .drawer-side {
    @apply px-4 py-8 border-r border-r-grey-600;
  }

  .menu {
    @apply pt-10 space-y-2;
  }
</style>
