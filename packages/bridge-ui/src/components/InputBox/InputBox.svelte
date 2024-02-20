<script lang="ts">
  import { classNames } from '$libs/util/classNames';

  export let error = false;
  let inputElement: HTMLInputElement;

  export let value: string | number | number[] = '';

  $: disabled = $$props.disabled || false;

  let classes = classNames(
    'w-full input-box bg-neutral-background shadow-none placeholder:text-tertiary-content font-bold shadow-none outline-none ',
    disabled ? 'cursor-not-allowed ' : 'cursor-pointer',
    $$props.class,
  );

  // Public API
  export const setValue = (value: string) => (inputElement.value = value);
  export const getValue = () => inputElement.value;
  export const clear = () => setValue('');
  export const focus = () => inputElement.focus();
</script>

<input bind:value bind:this={inputElement} {...$$restProps} class={classes} class:error on:input on:blur />
