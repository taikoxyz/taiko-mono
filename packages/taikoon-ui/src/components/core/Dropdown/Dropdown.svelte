<script lang="ts">
  import { classNames } from '../../../lib/util/classNames';
  import type { IDropdownItem } from '../../../types';
  import { Button } from '../Button';
  import { default as DropdownPanel } from './DropdownPanel.svelte';

  const buttonClasses = classNames('text-lg');

  export let options: IDropdownItem[] = [];
  export let label: string = 'Label';

  $: displayPanel = false;
</script>

<div
  class={classNames('relative')}
  on:mouseover={() => (displayPanel = true)}
  on:focus={() => (displayPanel = true)}
  on:mouseleave={() => (displayPanel = false)}
  role="button"
  tabindex="0">
  <Button type="ghost" class={buttonClasses} iconRight={'PlusSolid'}>
    {label}
  </Button>

  {#if displayPanel}
    <DropdownPanel {options} />
  {/if}
</div>
