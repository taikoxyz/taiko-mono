import { classNames } from '$lib/util/classNames';
export const wrapperClasses = classNames(
  'h-max',
  'w-full',
  'flex',
  'md:flex-row',
  'flex-col',
  'items-center',
  'justify-center',
  'md:px-5',
  'p-2',
  'gap-8',
  'md:py-16',
);

export const halfPanel = classNames(
  'h-full',
  'md:w-max',
  'flex flex-col',
  'items-center',
  'justify-center',
  'gap-2',
  'bg-neutral-background',
  'rounded-3xl',
  'p-8',
  'w-full',
);

export const leftHalfPanel = classNames(halfPanel, 'aspect-square');

export const rightHalfPanel = classNames(halfPanel, 'md:px-12', 'md:max-w-[500px]');

export const counterClasses = classNames(
  'w-full',
  'flex',
  'flex-row',
  'items-center',
  'justify-between',
  'font-sans',
  'font-bold',
  'mt-6',
);

export const nftRendererWrapperClasses = 'rounded-3xl overflow-hidden';
export const nftRendererWrapperMobileClasses = 'rounded-3xl my-8 overflow-hidden';

export const mintTitleClasses = 'w-full text-left';
export const mintContentClasses = 'font-normal font-sans text-content-secondary';
