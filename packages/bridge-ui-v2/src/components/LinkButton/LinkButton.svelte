<script lang="ts">
  type LinkTarget = '_blank' | '_self';

  export let active = false;
  export let href = '/';
  export let target: LinkTarget = '_self';
</script>

<a
  {href}
  {target}
  class="btn rounded-full body-bold flex justify-start content-center"
  class:bg-primary-interactive={active}>
  <slot />
</a>
