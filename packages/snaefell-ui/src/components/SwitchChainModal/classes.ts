import { classNames } from '$lib/util/classNames';

export const modalDialogClasses = classNames('modal', 'modal-bottom', 'md:modal-middle');

export const modalWrapperClasses = classNames(
  'modal-box',
  'relative',
  'px-6',
  'py-[35px]',
  'md:py-[35px]',
  'bg-neutral-background',
  'text-primary-content',
  'box-shadow-small',
);

export const titleClasses = classNames('title-body-bold', 'mb-[30px]');
export const textClasses = classNames('body-regular', 'mb-[20px]');

export const chainItemClasses = classNames(
  'p-4 rounded-[10px]',
  'hover:bg-primary-background',
  'cursor-pointer',
  'w-full',
);

export const chainItemContentClasses = classNames('f-row', 'f-items-center', 'justify-between', 'w-full');

export const chainItemContentWrapperClasses = classNames('f-items-center', 'space-x-4');
