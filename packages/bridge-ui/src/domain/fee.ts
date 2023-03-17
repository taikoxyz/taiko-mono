export enum ProcessingFeeMethod {
  RECOMMENDED = 'recommended',
  CUSTOM = 'custom',
  NONE = 'none',
}

export interface ProcessingFeeDetails {
  displayText: string;
  timeToConfirm: number;
}
