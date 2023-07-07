<script lang="ts">
  import { Icon, type IconType } from '$components/Icon';
  import { classNames } from '$libs/util/classNames';

  type TypeToast = 'success' | 'error' | 'warning' | 'unknown';

  export let type: TypeToast = 'unknown';
  export let message: string = '';

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
    'rounded-full',
    'min-w-[215px]',
    'max-w-[315px]',
    alertClassMap[type],
  );

  const messageClasses = classNames('callout-regular', messageClassMap[type]);
</script>

<div role="alert" class={alertClasses}>
  <div class="flex space-x-[5px]">
    <Icon type={iconTypeMap[type]} size={24} fillClass={alertIconClassMap[type]} />
    <div class={messageClasses}>{message}</div>
  </div>
  <button class="ml-6">
    <Icon type="x-close" size={32} fillClass={iconCloseClassMap[type]} />
  </button>
</div>
