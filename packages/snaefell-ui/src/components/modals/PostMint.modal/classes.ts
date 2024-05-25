import { classNames } from '$lib/util/classNames';

export const buttonWrapperClasses = classNames('md:w-1/2', 'w-full', 'px-2');
export const mintedBodyClasses = classNames('justify-start', 'gap-6', 'py-6', 'items-center');

export const successTitleClasses = classNames(
  'text-content-primary',
  'text-[35px]/[42px]',
  'font-clash-grotesk',
  'font-semibold',
  'text-center',
);

export const successContentClasses = classNames(
  'font-sans',
  'text-center',
  'text-content-secondary',
  'font-normal',
  'text-[16px]/[24px]',
  'md:w-min',
  'md:min-w-[300px]',
  'w-full',
);

export const successMintedLinkClasses = classNames(
  'hover:text-content-link-hover',
  'text-content-link-primary',
  'font-sans',
  'font-normal',
);

export const successFooterWrapperClasses = classNames(
  'flex',
  'md:flex-row',
  'flex-col',
  'w-full',
  'gap-4',
  'items-center',
  'justify-between',
  'min-w-[500px]',
);
