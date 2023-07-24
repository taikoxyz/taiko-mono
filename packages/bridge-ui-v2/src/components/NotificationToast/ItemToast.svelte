<script lang="ts">
  import { noop } from 'svelte/internal';

  import { Icon, type IconType } from '$components/Icon';
  import { classNames } from '$libs/util/classNames';

  import type { TypeToast } from './types';

  export let type: TypeToast = 'unknown';
  export let message = '';
  export let close: () => void = noop;

  const iconTypeMap: Record<TypeToast, IconType> = {
    success: 'check-circle',
    error: 'x-close-circle',
    warning: 'info-circle',
    unknown: 'question-circle',
  };

  const alertClassMap: Record<TypeToast, string> = {
    success: 'bg-positive-background',
    error: 'bg-negative-background',
    warning: 'bg-warning-background',
    unknown: 'bg-neutral-background',
  };

  const alertIconClassMap: Record<TypeToast, string> = {
    success: 'fill-positive-sentiment',
    error: 'fill-negative-sentiment',
    warning: 'fill-warning-sentiment',
    unknown: 'fill-primary-content',
  };

  const messageClassMap: Record<TypeToast, string> = {
    success: 'text-positive-sentiment',
    error: 'text-negative-sentiment',
    warning: 'text-warning-sentiment',
    unknown: 'text-primary-content',
  };

  const iconCloseClassMap: Record<TypeToast, string> = {
    success: 'fill-green-600',
    error: 'fill-red-500',
    warning: 'fill-yellow-500',
    unknown: 'fill-grey-5',
  };

  const alertClasses = classNames(
    'flex',
    'f-between-center',
    'py-3',
    'px-[20px]',
    'w-full',
    'rounded-full',
    alertClassMap[type],
  );

  const messageClasses = classNames('callout-regular', messageClassMap[type]);
</script>

<div role="alert" class={alertClasses}>
  <div class="grid grid-cols-[24px_auto] items-center space-x-2">
    <Icon type={iconTypeMap[type]} size={24} fillClass={alertIconClassMap[type]} />
    <!-- eslint-disable-next-line svelte/no-at-html-tags -->
    <div class={messageClasses}>{@html message}</div>
  </div>
  <button class="ml-6" on:click={close}>
    <Icon type="x-close" size={24} fillClass={iconCloseClassMap[type]} />
  </button>
</div>
