import { classNames } from '$lib/util/classNames';

export const connectedButtonClasses = classNames(
  'border border-divider-border',
  'bg-gradient-to-r from-grey-500-10 to-grey-500-20',
  'rounded-full',
  'flex',
  'items-center',
  'gap-2',
  'font-bold',
);

export const buttonContentClasses = classNames(
  'flex items-center',
  'justify-center',
  'text-secondary-content',
  'p-1',
  'gap-2',
  'md:text-normal',
  'text-sm',
);

export const addressClasses = classNames(
  'flex',
  'rounded-full',
  'p-2.5',
  'bg-neutral-background',
  'border border-divider-border',
);

export const chainIconClasses = classNames('w-[24px]', 'ml-1');
