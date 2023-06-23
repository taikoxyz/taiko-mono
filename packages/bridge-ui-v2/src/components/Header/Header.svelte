<script lang="ts">
  import { t } from '$libs/i18n';

  import Button from '../Button';
  import Icon from '../Icon';
  import Logo from '../Logo';
  import { drawerToogleId } from '../SideNavigation';
</script>

<header class="sticky md:px-10 md:py-7 flex justify-between items-center">
  <div class="flex space-x-2 items-center md:hidden">
    <label for={drawerToogleId} class="btn btn-ghost drawer-button">
      <Icon type="bars-menu" />
    </label>
    <Logo />
  </div>

  <span>TODO</span>

  <Button class="rounded-full" type="neutral">
    <Icon type="user-circle" />
    <span>{$t('wallet.connect')}</span>
  </Button>
</header>
