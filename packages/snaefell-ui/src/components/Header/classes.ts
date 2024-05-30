import { classNames } from '$lib/util/classNames';
export const baseHeaderClasses = classNames(
  'md:px-10',
  'md:py-10',
  'h-16',
  'flex flex-row',
  'justify-between',
  'items-center',
  'gap-4',
  'relative',
  'z-50',
  'px-6',
  'py-10',
);

export const taikoonsIconClasses = classNames('h-full');

export const rightSectionClasses = classNames(
  'md:right-8',
  'right-6',
  'w-max',
  'absolute',
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

export const menuButtonsWrapperClasses = classNames(
  'w-full',
  'justify-center',
  'items-center',
  'gap-4',
  'flex',
  'flex-row',
);

export const wrapperClasses = classNames('w-full', 'z-0', 'fixed', 'top-0');

export const themeButtonSeparatorClasses = 'v-sep my-auto ml-0 mr-4 h-[24px]';

export const navButtonClasses = classNames(
  'w-[140px]',
  'h-[44px]',
  'bg-nav-button',
  'flex flex-row',
  'justify-center',
  'tracking-[-2%]',
  'items-center',
  'rounded-full',
  'font-sans',
  'font-medium',
  'text-base/[135.5%]',
  'text-content-primary',
);

export const logoClasses = classNames('flex', 'flex-row', 'justify-center', 'items-center');
