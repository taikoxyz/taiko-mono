import { classNames } from '$lib/util/classNames';

export const filterFormWrapperClasses = classNames(
  'z-10',
  'w-full',
  'flex',
  'flex-col',
  'md:flex-row',
  'md:p-5',
  'gap-5',
  'md:items-center',
  'items-end',
  'justify-between',
);

export const wrapperClasses = classNames(
  'h-full',
  'w-full',
  'flex',
  'flex-row',
  'items-start',
  'justify-evenly',
  'pt-36',
  'px-4',
  'gap-10',
  'z-0',
);

export const taikoonsWrapperClasses = classNames(
  'h-full',
  'z-0',
  'overflow-x-hidden',
  'w-7/10',
  'gap-5',
  'p-5',
  'grid',
  'xl:grid-cols-8',
  'lg:grid-cols-6',
  'md:grid-cols-4',
  'grid-cols-3',
  'auto-rows-max',
);

export const detailClasses = classNames(
  'bg-neutral-background',
  'py-5',
  'px-10',
  'gap-3',
  'flex',
  'flex-col',
  'items-center',
  'justify-start',
  'rounded-t-3xl',
  'h-full',
  'w-96',
);

export const detailContainerClasses = classNames(
  'w-full',
  'flex',
  'gap-3',
  'my-2',
  'flex-col',
  'items-center',
  'justify-start',
);

export const detailTitleClasses = classNames(
  'my-2',
  'text-left',
  'w-full',
  'text-5xl',
  'font-clash-grotesk',
  'font-semibold',
);

export const chipWrapperClasses = classNames('my-2', 'flex', 'flex-row', 'w-full', 'justify-start');

export const titleClasses = classNames(
  'font-clash-grotesk',
  'text-[57px]/[64px]',
  'text-content-primary',
  'font-semibold',
);
