<script lang="ts">
  import { Icons } from '$ui/Icons';

  import { classNames } from '../../../lib/util/classNames';
  import type { IconType } from '../../../types';

  type ButtonType =
    | 'neutral'
    | 'primary'
    | 'secondary'
    | 'accent'
    | 'info'
    | 'success'
    | 'warning'
    | 'error'
    | 'ghost'
    | 'link';

  const typeMap: Record<ButtonType, string> = {
    neutral: 'btn-neutral',
    primary: 'btn-primary',
    secondary: 'btn-secondary',
    accent: 'btn-accent',
    info: 'btn-info',
    success: 'btn-success',
    warning: 'btn-warning',
    error: 'btn-error',
    ghost: 'btn-ghost',
    link: 'btn-link',
  };

  export let icon: string = '';
  export let size: 'xs' | 'sm' | 'md' | 'lg' | 'xl' = 'md';
  export let type: ButtonType = 'neutral';

  $: IconComponent = Icons[icon as IconType];

  const iconSizes = {
    xs: 14,
    sm: 16,
    md: 24,
    lg: 28,
    xl: 32,
  };

  $: iconSize = iconSizes[size];

  $: iconClasses = classNames();

  $: buttonClasses = classNames(
    'btn',
    type ? typeMap[type] : null,
    'btn-circle',
    'border-none',
    //  'w-12',
    //  'h-12',
    'flex items-center justify-center',
    'p-0',
    type === 'neutral' ? 'bg-interactive-tertiary' : null,
    type === 'primary' ? 'text-[#F3F3F3]' : null,

    size === 'md' ? 'w-12 h-12' : null,
    size === 'lg' ? 'w-14 h-14' : null,
    $$props.class,
  );
</script>

<button {...$$restProps} class={buttonClasses} on:click>
  <svelte:component this={IconComponent} size={iconSize.toString()} class={iconClasses} />
</button>
