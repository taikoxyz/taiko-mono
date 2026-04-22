<script lang="ts">
  import { classNames } from '../../../lib/util/classNames';
  import { P } from '../Text/';
  import type { TypeToast } from './types';
  export let type: TypeToast = 'unknown';
  export let title = '';
  export let message: string | undefined;

  const alertClassMap: Record<TypeToast, string> = {
    success: 'bg-positive-background',
    error: 'bg-negative-background',
    warning: 'bg-warning-background',
    info: 'bg-primary-interactive',
    unknown: 'bg-elevated-background',
  };

  const alertClasses = classNames(
    'flex',
    'flex-col',
    'py-3',
    'px-5',
    'w-full',
    'h-max',
    'rounded-xl',
    alertClassMap[type],
  );

  const titleClasses = classNames('text-xl', 'font-bold');
</script>

<div role="alert" class={alertClasses}>
  <div class={titleClasses}>{title}</div>
  {#if message}
    <P class="mt-2">{message}</P>
  {/if}
</div>
