import { classNames } from '$lib/util/classNames';
export const wrapperClasses = classNames(
  'h-max',
  'flex',

  'items-center',
  'justify-center',
  'bg-neutral-background',
  'rounded-3xl',
  'gap-12',
  // mobile
  'py-4',
  'px-1',
  'mt-2.5',
  'flex-col',
  'w-[calc(100%-1.5rem)]',
  // regular
  'md:flex-row',
  'md:p-8',
  'md:mt-32',
  'md:max-w-[95vw]',
  'md:w-max',
);

export const halfPanel = classNames(
  'h-max',
  'md:w-max',
  'flex flex-col',
  'items-center',
  'justify-center',
  'gap-2',
  'rounded-3xl',
  'w-full',
);

export const leftHalfPanel = classNames('max-w-[473px]', 'aspect-square');

export const rightHalfPanel = classNames(halfPanel, 'min-w-[200px]', 'px-[20px]', 'max-w-[400px]', 'w-full');

export const counterClasses = classNames(
  'w-full',
  'flex',
  'flex-row',
  'items-center',
  'justify-between',
  'font-sans',
  'mt-6',
);

export const nftRendererWrapperClasses = 'rounded-3xl overflow-hidden';
export const nftRendererWrapperMobileClasses = 'rounded-3xl lg:my-8 my-4 overflow-hidden aspect-square';

export const mintTitleClasses = classNames(
  'text-[45px]/[52px]',
  'font-semibold',
  'text-content-primary',
  'font-clash-grotesk',
  'tracking-[-1%]',
  'w-full text-left',
);
export const mintContentClasses = classNames(
  'font-normal',
  'font-sans',
  'my-2',
  'text-content-secondary',
  'text-[16px]/[24px]',
);

export const eligibilityLabelClasses = classNames(
  'text-content-primary',
  'text-[16px]/[24px]',
  'text-normal',
  'font-sans',
);

export const eligibilityValueClasses = classNames(
  'text-content-primary',
  'text-[16px]/[24px]',
  'font-bold',
  'font-sans',
  'tracking-[0.5%]',
);

export const currentMintedClasses = classNames(
  'font-sans',
  'font-bold',
  'text-content-primary',
  'tracking-[0.5%]',
  'text-[16px]/[24px]',
);
export const maxMintedClasses = classNames(
  'text-content-tertiary',
  'font-bold',
  'text-[16px]/[24px]',
  'tracking-[0.5%]',
);

export const infoRowClasses = classNames('w-full', 'gap-4', 'flex', 'flex-col');
