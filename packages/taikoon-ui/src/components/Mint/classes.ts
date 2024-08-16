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

export const rightHalfPanel = classNames(
  halfPanel,
  'md:px-12',
  'min-w-[400px]',
  'my-16',
  'md:my-[0]',
  'md:max-w-[500px]',
);

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
export const nftRendererWrapperMobileClasses = 'rounded-3xl my-8 overflow-hidden';

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
