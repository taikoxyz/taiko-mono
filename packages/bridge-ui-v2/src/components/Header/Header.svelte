<script lang="ts">
  import { t } from 'svelte-i18n';

  import { Button } from '$components/Button';
  import { Icon } from '$components/Icon';
  import { LogoWithText } from '$components/Logo';
  import { drawerToggleId } from '$components/SideNavigation';
  import { web3modal } from '$libs/connect';
</script>

<header
  class="
    f-between-center
    py-[20px] 
    px-4 
    border-b 
    border-b-divider-border 
    md:border-b-0 
    md:px-10 md:py-7 
    md:justify-end">
  <LogoWithText class="w-[77px] h-[20px] md:hidden" />

  <div class="f-items-center justify-end space-x-[10px]">
    <Button class="px-[20px] py-2 rounded-full" type="neutral" on:click={() => web3modal.openModal()}>
      <Icon type="user-circle" class="md-show-block" />
      <span class="body-small-regular">{$t('wallet.connect')}</span>
    </Button>
    <label for={drawerToggleId} class="md:hidden">
      <Icon type="bars-menu" />
    </label>
  </div>

  <!-- TODO: think about the possibility of actually using w3m-core-button component -->
  <!-- <w3m-core-button balance="show" icon="hide" /> -->
</header>
