<script lang="ts">
  type LinkTarget = '_blank' | '_self';

  export let active = false;
  export let href = '/';
  export let target: LinkTarget = '_self';
</script>

<a {href} {target} class:bg-primary-interactive={active}>
  <slot />
</a>

<style lang="postcss">
  a {
    @apply btn rounded-full flex justify-start items-center;
  }
</style>
