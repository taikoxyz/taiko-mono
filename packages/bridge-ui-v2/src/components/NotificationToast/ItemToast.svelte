<script lang="ts">
  import { Icon, type IconType } from '$components/Icon';
  import { classNames } from '$libs/util/classNames';
  import { noop } from '$libs/util/noop';

  import type { TypeToast } from './types';

  export let type: TypeToast = 'unknown';
  export let title = '';
  export let message: string | undefined;
  export let close: () => void = noop;

  const iconTypeMap: Record<TypeToast, IconType> = {
    success: 'check-circle',
    error: 'x-close-circle',
    warning: 'info-circle',
    info: 'info-circle',
    unknown: 'question-circle',
  };

  const alertClassMap: Record<TypeToast, string> = {
    success: 'bg-positive-background',
    error: 'bg-negative-background',
    warning: 'bg-warning-background',
    info: 'bg-primary-interactive',
    unknown: 'bg-neutral-background',
  };

  const alertIconClassMap: Record<TypeToast, string> = {
    success: 'fill-positive-sentiment',
    error: 'fill-negative-sentiment',
    warning: 'fill-warning-sentiment',
    info: 'fill-pink-50',
    unknown: 'fill-primary-content',
  };

  const messageClassMap: Record<TypeToast, string> = {
    success: 'text-positive-sentiment',
    error: 'text-negative-sentiment',
    warning: 'text-warning-sentiment',
    info: 'text-white',
    unknown: 'text-primary-content',
  };

  const iconCloseClassMap: Record<TypeToast, string> = {
    success: 'fill-green-600',
    error: 'fill-red-500',
    warning: 'fill-yellow-500',
    info: 'fill-pink-200',
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

  const messageClasses = classNames(messageClassMap[type]);
</script>

<div role="alert" class={alertClasses}>
  <div class="grid grid-cols-[24px_auto] items-center space-x-2">
    <Icon type={iconTypeMap[type]} size={24} fillClass={alertIconClassMap[type]} />
    <div class={messageClasses}>
      <!-- eslint-disable-next-line svelte/no-at-html-tags -->
      <div class="callout-bold leading-[24px]">{@html title}</div>
      {#if message}
        <!-- eslint-disable-next-line svelte/no-at-html-tags -->
        <div class="callout-regular">{@html message}</div>
      {/if}
    </div>
  </div>
  <button class="ml-6" on:click={close}>
    <Icon type="x-close" size={24} fillClass={iconCloseClassMap[type]} />
  </button>
</div>
