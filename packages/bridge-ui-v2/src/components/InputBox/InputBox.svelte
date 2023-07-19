<script lang="ts">
  import { classNames } from '$libs/util/classNames';

  let input: HTMLInputElement;
  let classes = classNames('w-full input-box placeholder:text-tertiary-content', $$props.class);

  export let loading = false;

  // Public API
  export const getValue = () => input.value;
  export const setValue = (value: string) => (input.value = value);
  export const clear = () => setValue('');
  export const focus = () => input.focus();
</script>

<input class={classes} disabled={loading} {...$$restProps} on:input bind:this={input} />
