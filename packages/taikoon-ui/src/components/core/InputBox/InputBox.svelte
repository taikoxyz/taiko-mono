<script lang="ts">
  import { classNames } from '../../../lib/util/classNames';

  export let error = false;
  let inputElement: HTMLInputElement;

  export let value: string | number | number[] = '';
  export let size: 'sm' | 'md' | 'lg' = 'md';
  export let width: 'full' | 'auto' | 'min' | 'half' = 'full';

  $: disabled = $$props.disabled || false;

  let classes = classNames(
    'input-box',
    'bg-elevated-background',
    'shadow-none',
    'placeholder:text-tertiary-content',
    'font-bold',
    'shadow-none',
    'outline-none ',
    disabled ? 'cursor-not-allowed ' : 'cursor-pointer',

    size === 'sm' ? 'py-1 px-2 rounded-xl' : null,
    size === 'md' ? 'py-2 px-3 rounded-2xl' : null,
    size === 'lg' ? 'py-5 px-6 rounded-3xl' : null,

    // width === 'full' ? 'w-full' : null,
    width === 'auto' ? 'w-auto' : null,
    width === 'min' ? 'w-min' : null,
    width === 'half' ? 'w-1/2' : null,

    $$props.class,
  );

  // Public API
  export const setValue = (value: string) => (inputElement.value = value);
  export const getValue = () => inputElement.value;
  export const clear = () => setValue('');
  export const focus = () => inputElement.focus();
</script>

<input bind:value bind:this={inputElement} {...$$restProps} class={classes} class:error on:input on:blur />
