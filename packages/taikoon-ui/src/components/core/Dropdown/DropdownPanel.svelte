<script lang="ts">
  import { slide } from 'svelte/transition';

  import { classNames } from '../../../lib/util/classNames';
  import type { IDropdownItem } from '../../../types';
  import { Icons } from '../Icons';
  export let options: IDropdownItem[] = [];

  const panelClasses = classNames('absolute', 'pt-3', 'bg-transparent', 'w-full');

  const itemClasses = classNames(
    'w-full',
    'flex flex-row',
    'items-center justify-start',
    'first:rounded-t-lg',
    'last:rounded-b-lg',
    'bg-elevated-background',
    'p-4',
    'gap-6',
    'transition',
    'hover:text-primary',
    'cursor-pointer',
  );
</script>

<div class={panelClasses} transition:slide={{ duration: 300 }}>
  {#each options as option}
    {@const Icon = Icons[option.icon]}

    <a href={option.href} class={itemClasses}>
      <span class="text-primary"><Icon size="16" /></span>
      {option.label}
    </a>
  {/each}
</div>
