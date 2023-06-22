<script lang="ts">
  import Button from '../Button';
  import Icon from '../Icon';
  import Logo from '../Logo';
  import { drawerToogleId } from '../SideNavigation';
</script>

<header class="sticky md:px-10 md:py-7 flex justify-between">
  <div class="flex space-x-2 items-center md:hidden">
    <label for={drawerToogleId} class="btn btn-ghost drawer-button">
      <Icon type="bars-menu" />
    </label>
    <Logo />
  </div>

  <Button>Connect Wallet</Button>
</header>
