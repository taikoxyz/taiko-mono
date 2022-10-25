<script>
  import ConnectButton from "./ConnectButton.svelte";
  import ThemeChanger from "./ThemeChanger.svelte";
</script>

<div class="navbar bg-base-100">
  <div class="flex-none">
    <ThemeChanger />
  </div>
  <div class="flex-1">
    <span class="btn btn-ghost normal-case text-xl"> Bridge </span>
  </div>
  <div class="flex-none">
    <ConnectButton />
  </div>
</div>
