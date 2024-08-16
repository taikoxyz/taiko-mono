import { classNames } from '$lib/util/classNames';

export const modalContentWrapperClasses = classNames('sm:w-full', 'md:w-[60vw]', 'lg:w-[50vw]');
export const modalTitleClasses = classNames('sm:mt-[0]', 'mx-4', 'pt-6');
export const bodyWrapperClasses = classNames('text-content-secondary', 'm-4');
export const footerWrapperClasses = classNames('w-full', 'flex', 'flex-row', 'items-center', 'justify-center', 'gap-4');
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
export const linkClasses = classNames('text-secondary', 'cursor-pointer');
