<script lang="ts">
  export let title: string = '';
  export let text = '';
</script>

<div class="card w-full md:w-[524px] bg-elevated-background rounded-[20px] border border-neutral-background">
  <div class="card-body p-12 body-regular">
    {#if title}
      <h2 class="card-title title-screen-bold">{title}</h2>
    {/if}
    {#if text}
      <p>{text}</p>
    {/if}
    <slot />
  </div>
</div>
