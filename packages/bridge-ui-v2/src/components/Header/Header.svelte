<script lang="ts">
  import { ConnectButton } from '$components/ConnectButton';
  import { Icon } from '$components/Icon';
  import { LogoWithText } from '$components/Logo';
  import { drawerToggleId } from '$components/SideNavigation';
  import { account } from '$stores/account';
</script>

<header
  class="
    sticky-top
    f-between-center
    z-10
    px-4
    py-[20px]
    border-b
    border-b-divider-border
    glassy-primary-background
    md:border-b-0
    md:px-10
    md:py-7
    md:justify-end">
  <LogoWithText class="w-[77px] h-[20px] md:hidden" />

  <div class="f-items-center justify-end space-x-[10px]">
    <ConnectButton connected={$account?.isConnected} />

    <label for={drawerToggleId} class="md:hidden">
      <Icon type="bars-menu" />
    </label>
  </div>
</header>
