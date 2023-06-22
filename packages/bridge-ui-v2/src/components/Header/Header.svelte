<script lang="ts">
  import { drawerToogleId } from '../SideNavigation';
  import Icon from '../Icon';
  import Logo from '../Logo';
</script>

<div class="Header">
  <header class="sticky p-2 md:py-7 md:px-10 flex justify-between">
    <div class="flex space-x-2 items-center md:hidden">
      <label for={drawerToogleId} class="btn btn-ghost drawer-button">
        <Icon type="bars-menu" />
      </label>
      <Logo />
    </div>
  </header>
</div>
