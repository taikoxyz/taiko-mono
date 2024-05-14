import { classNames } from '$lib/util/classNames';

export const bodyWrapperClasses = 'text-content-secondary';
export const footerWrapperClasses = 'w-full flex flex-row items-center gap-4';
export const spinnerSmWrapper = 'bg-interactive-tertiary rounded-md w-[30px] h-[30px] flex items-center justify-center';
export const spinnerMdWrapper = 'w-full flex justify-center items-center';
export const textClasses = 'font-sans font-bold text-sm text-content-primary';
export const linkClasses = 'flex flex-row items-center gap-2';
export const mintedBodyClasses = 'justify-start gap-6 py-6 items-center';
export const buttonWrapperClasses = 'md:w-1/2 w-full px-2';

export const successBodyClasses = classNames(
  'max-w-[50vw]',
  'p-5',
  'rounded-3xl',
  'my-5',
  'bg-background-elevated',
  'flex',
  'overflow-x-scroll',
);
export const nftRendererWrapperClasses = classNames(
  'flex',
  'flex-row',
  'justify-start',
  'items-start',
  'gap-5',
  'w-max',
);

export const successTitleClasses = classNames(
  'text-content-primary',
  'text-4xl',
  'font-clash-grotesk',
  'font-semibold',
  'text-center',
);

export const successContentClasses = classNames(
  'font-sans',
  'text-center',
  'text-content-secondary',
  'font-normal',
  'text-base',
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
