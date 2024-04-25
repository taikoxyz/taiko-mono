<script lang="ts">
  import { classNames } from '../../../lib/util/classNames';
  import type { IDropdownItem } from '../../../types';
  import { Icons } from '../Icons';
  import { default as SelectPanel } from './SelectPanel.svelte';

  const AngleDownSolid = Icons.AngleDownSolid;
  const buttonClasses = classNames(
    'text-lg',
    'bg-neutral-background',
    'py-4',
    'px-8',
    'flex',
    'flex-row',
    'items-center',
    'justify-between',
    'gap-8',
    'rounded-3xl',
    'text-text-light',
  );

  export let options: IDropdownItem[] = [];
  export let label: string = 'Label';
  export let onSelect: (value: string) => void;

  $: displayPanel = false;

  function _onSelect(value: string) {
    onSelect(value);
    label = options.find((option) => option.value === value).label;
  }
</script>

<div
  class={classNames('relative')}
  on:mouseover={() => (displayPanel = true)}
  on:focus={() => (displayPanel = true)}
  on:mouseleave={() => (displayPanel = false)}
  role="button"
  tabindex="0">
  <div class={buttonClasses}>
    {label}
    <AngleDownSolid size={16} />
  </div>

  {#if displayPanel}
    <SelectPanel onSelect={_onSelect} {options} />
  {/if}
</div>
