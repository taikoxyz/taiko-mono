import { classNames } from '$lib/util/classNames';
export const wrapperClasses = 'items-center justify-center';
export const textContainerClasses = classNames(
  'p-8',
  'my-4',
  'h-[50vh]',
  'w-[90vw]',
  'rounded-3xl',
  'overflow-y-scroll',
  'bg-elevated-background',
);

export const buttonRowClasses = classNames(
  'flex',
  'md:flex-row',
  'flex-col',
  'w-full',
  'items-center',
  'justify-evenly',
  'gap-4',
  'py-4',
);

export const buttonClasses = classNames('w-full', 'md:w-1/2');
