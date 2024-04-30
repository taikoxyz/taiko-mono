import { classNames } from '$lib/util/classNames';
export const headerClasses = classNames(
  'md:px-10',
  'md:py-10',
  'h-16',
  'flex flex-row',
  'justify-between',
  'items-center',
  'gap-4',
  'relative',
  'z-50',
  'px-4',
  'md:glassy-background-lg',
  'md:border-b-[1px] md:border-border-divider-default',
);

export const buttonClasses = classNames('text-lg', 'w-min', 'lg:w-[200px]');

export const taikoonsIconClasses = classNames('h-full');

export const rightSectionClasses = classNames(
  'md:right-8',
  'right-4',
  'w-max',
  'flex flex-row justify-center items-center',
  'gap-4',
);

export const mobileMenuButtonClasses = classNames(
  'bg-interactive-tertiary',
  'rounded-full',
  'w-[50px]',
  'h-[50px]',
  'flex justify-center items-center',
);

export const menuButtonsWrapperClasses = classNames('w-max', 'gap-4', 'flex', 'flex-row');

export const wrapperClasses = classNames('w-full', 'z-0', 'fixed', 'top-0');

export const themeButtonSeparatorClasses = 'v-sep my-auto ml-0 mr-4 h-[24px]';
