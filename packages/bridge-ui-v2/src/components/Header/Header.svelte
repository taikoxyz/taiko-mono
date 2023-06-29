<script lang="ts">
  import { t } from 'svelte-i18n';

  import { web3modal } from '$libs/connect';

  import { Button } from '../Button';
  import { Icon } from '../Icon';
  import { LogoWithText } from '../Logo';
  import { drawerToggleId } from '../SideNavigation';
</script>

<header class="sticky py-[20px] px-4 md:px-10 md:py-7 f-center md:justify-end">
  <LogoWithText class="w-[77px] h-[20px] md:hidden" />

  <div class="f-items-center justify-end space-x-[10px]">
    <Button on:click={() => web3modal.openModal()} class="rounded-full" type="neutral">
      <Icon type="user-circle" />
      <span>{$t('wallet.connect')}</span>
    </Button>
    <label for={drawerToggleId} class="md:hidden">
      <Icon type="bars-menu" />
    </label>
  </div>

  <!-- TODO: think about the possibility of actually using w3m-core-button component -->
  <!-- <w3m-core-button balance="show" icon="hide" /> -->
</header>
