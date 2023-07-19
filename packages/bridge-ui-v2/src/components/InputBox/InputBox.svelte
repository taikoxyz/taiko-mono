<script lang="ts">
  import { classNames } from '$libs/util/classNames';

  export let loading = false;
  export let error = false;

  let input: HTMLInputElement;
  let classes = classNames('w-full input-box placeholder:text-tertiary-content', $$props.class);

  // Public API
  export const getValue = () => input.value;
  export const setValue = (value: string) => (input.value = value);
  export const clear = () => setValue('');
  export const focus = () => input.focus();
</script>

<input class={classes} class:error disabled={loading} {...$$restProps} bind:this={input} on:input on:blur />
