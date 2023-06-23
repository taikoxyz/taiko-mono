<script lang="ts">
  import { web3modal } from '$libs/connect';
  import { t } from '$libs/i18n';

  import Button from '../Button';
  import Icon from '../Icon';
  import { LogoWithText } from '../Logo';
  import { drawerToogleId } from '../SideNavigation';
</script>

<header class="sticky p-2 md:px-10 md:py-7 flex justify-between md:justify-end items-center">
  <div class="flex space-x-2 items-center md:hidden">
    <label for={drawerToogleId} class="btn btn-sm md:btn-md btn-ghost drawer-button">
      <Icon type="bars-menu" />
    </label>
    <LogoWithText class="w-[88px] h-[24px]" />
  </div>

  <Button on:click={() => web3modal.openModal()} class="rounded-full" type="neutral">
    <Icon type="user-circle" />
    <span>{$t('wallet.connect')}</span>
  </Button>
</header>
