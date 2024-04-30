import { classNames } from '$lib/util/classNames';

export const wrapperClasses = classNames('relative', 'flex', 'flex-row', 'items-center', 'justify-center');

const iconButtonClasses = classNames('relative', 'z-50');

export const leftIconButtonClasses = classNames(iconButtonClasses, 'left-[29px]');

export const rightIconButtonClasses = classNames(iconButtonClasses, 'left-[-29px]');
