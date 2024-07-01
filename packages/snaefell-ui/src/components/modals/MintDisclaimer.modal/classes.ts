import { classNames } from '$lib/util/classNames';

export const modalContentWrapperClasses = classNames('sm:w-full', 'md:w-[40vw]', 'lg:w-[40vw]');
export const modalTitleClasses = classNames(
  'sm:mt-[0]',
  'pt-6',

  'border-b-[1px]',
  'border-border-divider-default',
);
export const bodyWrapperClasses = classNames('text-content-primary', 'py-4');
export const footerWrapperClasses = classNames(
  'w-full',
  'flex',
  'flex-row',
  'items-center',
  'justify-center',
  'gap-4',
  'my-6',
  'md:mb-6',
);
export const spinnerSmWrapper = classNames(
  'bg-interactive-tertiary',
  'rounded-md',
  'w-[30px]',
  'h-[30px]',
  'flex',
  'items-center',
  'justify-center',
);
export const spinnerMdWrapper = classNames('w-full', 'flex', 'justify-center', 'items-center');
export const textClasses = classNames('font-sans', 'font-bold', 'text-sm', 'text-content-primary');
export const linkClasses = classNames('text-primary-link', 'cursor-pointer');
export const checkboxWrapperClasses = classNames(
  'label',
  'cursor-pointer',
  'flex',
  'flex-row',
  'justify-center',
  'gap-4',
  'my-6',
  'text-[16px]/[24px]',
  'items-center',
);
