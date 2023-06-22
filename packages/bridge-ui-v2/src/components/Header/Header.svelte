<script lang="ts">
  import Button from '../Button';
  import Icon from '../Icon';
  import Logo from '../Logo';
</script>

<div class="Header">
  <header class="sticky p-2 md:py-7 md:px-10 flex justify-between">
    <div class="flex space-x-2 items-center md:hidden">
      <Button type="ghost" class="md:hidden">
        <Icon type="bars-menu" />
      </Button>
      <Logo />
    </div>
  </header>
</div>
