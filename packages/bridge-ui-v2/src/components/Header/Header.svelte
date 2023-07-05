<script lang="ts">
  import { t } from 'svelte-i18n';

  import { Button } from '$components/Button';
  import { Icon } from '$components/Icon';
  import { LogoWithText } from '$components/Logo';
  import { drawerToggleId } from '$components/SideNavigation';
  import { web3modal } from '$libs/connect';

  let connectingWallet = false;

  async function connectWallet() {
    connectingWallet = true;
    try {
      await web3modal.openModal();
    } catch (error) {
      console.error(error);
    } finally {
      connectingWallet = false;
    }
  }
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
    <Button class="px-[20px] py-2 rounded-full" type="neutral" on:click={connectWallet}>
      <Icon type="user-circle" class="md-show-block" />
      <span class="body-small-regular">{$t('wallet.connect')}</span>
    </Button>
    <label for={drawerToggleId} class="md:hidden">
      <Icon type="bars-menu" />
    </label>
  </div>

  {#if !connectingWallet}
    <!-- TODO: think about the possibility of actually using w3m-core-button component -->
    <w3m-core-button balance="show" />
  {/if}
</header>
