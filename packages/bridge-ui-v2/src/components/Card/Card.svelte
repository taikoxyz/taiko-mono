<script lang="ts">
  export let title = '';
  export let text = '';
</script>

<div class="card w-full md:w-[524px] md:bg-elevated-background rounded-[20px] md:border md:border-neutral-background">
  <div class="card-body p-4 md:p-12 body-regular">
    {#if title}
      <h2 class="card-title title-screen-bold">{title}</h2>
    {/if}
    {#if text}
      <p>{text}</p>
    {/if}
    <slot />
  </div>
</div>
