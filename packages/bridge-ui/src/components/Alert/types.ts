import type { IconType } from '$components/Icon';

export type AlertType = 'success' | 'warning' | 'error' | 'info';

export type AlertIconDetails = {
  iconType: IconType;
  iconFillClass: string;
};
