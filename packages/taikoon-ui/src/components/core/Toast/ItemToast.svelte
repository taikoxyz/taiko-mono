<script lang="ts">
  import { classNames } from '../../../lib/util/classNames';
  import { H5, P } from '../Text/';
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
</script>

<div role="alert" class={alertClasses}>
  <H5>{title}</H5>
  {#if message}
    <P class="mt-2">{message}</P>
  {/if}
</div>
