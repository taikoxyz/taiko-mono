<script lang="ts">
  import { drawerToogleId } from '../SideNavigation';
  import Icon from '../Icon';
  import Logo from '../Logo';
</script>

<header class="sticky md:px-10 md:py-7 flex justify-between">
  <div class="flex space-x-2 items-center md:hidden">
    <label for={drawerToogleId} class="btn btn-ghost drawer-button">
      <Icon type="bars-menu" />
    </label>
    <Logo />
  </div>

  TODO: Header
</header>
