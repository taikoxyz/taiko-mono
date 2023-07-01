<script lang="ts">
  import { classNames } from '$libs/util/classNames';

  let input: HTMLInputElement;

  export let classes = classNames('w-full input-box placeholder:text-tertiary-content', $$props.class);

  export const clear = () => (input.value = '');
  export const focus = () => input.focus();
  export const value = () => input.value;
</script>

<input class={classes} {...$$restProps} on:input bind:this={input} />
