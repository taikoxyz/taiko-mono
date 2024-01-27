<script lang="ts">
  import { classNames } from '$libs/util/classNames';

  export let error = false;
  let inputElement: HTMLInputElement;

  export let value: string = '';

  $: disabled = $$props.disabled || false;

  let classes = classNames(
    'w-full input-box  placeholder:text-secondary-content bg-neutral-background shadow-none font-bold  shadow-none outline-none ',
    disabled ? 'hover:cursor-not-allowed' : 'hover:cursor-pointer',
    $$props.class,
  );

  // Public API
  export const setValue = (value: string) => (inputElement.value = value);
  export const clear = () => setValue('');
  export const focus = () => inputElement.focus();
</script>

<input bind:value bind:this={inputElement} {...$$restProps} class={classes} class:error on:input on:blur />
