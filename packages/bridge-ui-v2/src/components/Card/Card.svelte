<script lang="ts">
  import { classNames } from '$libs/util/classNames';

  export let title: string;
  export let text = '';

  export let classes = classNames(
    'card w-full md:bg-elevated-background rounded-[20px] md:border md:border-neutral-background',
    $$props.class,
  );
</script>

<div class={classes}>
  <div class="card-body body-regular p-0 md:p-[50px]">
    <h2 class="card-title title-screen-bold">{title}</h2>
    {#if text}
      <p>{text}</p>
    {/if}
    <div class="f-col mt-[35px]">
      <slot />
    </div>
  </div>
</div>
