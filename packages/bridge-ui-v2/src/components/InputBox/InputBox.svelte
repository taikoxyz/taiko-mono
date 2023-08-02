<script lang="ts">
  import { onMount } from 'svelte';

  import { classNames } from '$libs/util/classNames';

  export let loading = false;
  export let error = false;

  let input: HTMLInputElement;

  let { class: restClass = '', ...restProps } = $$restProps;
  let classes = classNames(
    'w-full input-box placeholder:text-tertiary-content bg-gray-700 border-0 shadow-none outline-none font-bold text-2xl',
    restClass,
    error ? 'error' : '',
  );

  // Public API
  export const getValue = () => input.value;
  export const setValue = (value: string) => (input.value = value);
  export const clear = () => setValue('');
  export const focus = () => input.focus();
</script>

<input class={classes} disabled={loading} {...restProps} bind:this={input} on:input on:blur />
