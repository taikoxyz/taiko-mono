import type { IconType } from '$components/Icon';

export enum AlertType {
	SUCCESS = 'success',
	WARNING = 'warning',
	ERROR = 'error',
	INFO = 'info'
}

export type AlertIconDetails = {
	iconType: IconType;
	iconFillClass: string;
};
