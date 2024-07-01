<script lang="ts">
  import { Icons } from '$components/core/Icons';
  import { classNames } from '$lib/util/classNames';
  export let isHovered = false;
  const ArrowIcon = Icons.ArrowRightFilled;

  const wrapperClasses = classNames(
    'bg-white',
    'rounded-full',
    'w-[32px]',
    'h-[32px]',
    'flex',
    'items-center',
    'justify-center',
    'overflow-hidden',
  );

  $: arrowsWrapper = classNames(
    'w-full',
    'h-full',
    'relative',
    'flex',
    'items-center',
    'justify-center',
    'transition',
    'transform',
    isHovered ? 'translate-x-[100%]' : null,
    'ease-in-out',
    'duration-300',
  );

  const arrowClasses = classNames('absolute');

  const leftArrowClasses = classNames(arrowClasses, 'left-[-100%]');

  const rightArrowClasses = classNames(arrowClasses);
</script>

<div class={wrapperClasses}>
  <div class={arrowsWrapper}>
    <ArrowIcon size="32" class={leftArrowClasses} />
    <ArrowIcon size="32" class={rightArrowClasses} />
  </div>
</div>
