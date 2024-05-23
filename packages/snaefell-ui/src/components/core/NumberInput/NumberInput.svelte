<script lang="ts">
  import { classNames } from '$lib/util/classNames';

  import { IconButton } from '../IconButton';
  import { InputBox } from '../InputBox';

  export let label: string = 'Label';
  export let disabled: boolean = true;
  export let min: number = 0;
  export let max: number = 0;
  export let value: number = 0;

  function onMinusClick() {
    if (value > min) {
      value -= 1;
    }
  }

  function onPlusClick() {
    if (value < max) {
      value += 1;
    }
  }

  $: disabled, disabled ? (value = 0) : null;

  const wrapperClasses = classNames('flex', 'flex-col', 'gap-2', 'my-4');
  const labelClasses = classNames('font-bold', 'text-sm', 'w-full', 'text-center');
  const contentWrapperClasses = classNames('flex', 'flex-row', 'gap-5', 'justify-center', 'text-text-dark');
  const inputClasses = classNames('bg-transparent', 'text-center', 'w-1/5');
</script>

<div class={wrapperClasses}>
  <p class={labelClasses}>{label}</p>

  <div class={contentWrapperClasses}>
    <IconButton on:click={onMinusClick} {disabled} icon="MinusSign" type="neutral" size="sm" />

    <InputBox class={inputClasses} width="half" {disabled} type="number" bind:value placeholder="0" />

    <IconButton on:click={onPlusClick} {disabled} size="sm" icon="PlusSign" type="primary" />
  </div>
</div>
