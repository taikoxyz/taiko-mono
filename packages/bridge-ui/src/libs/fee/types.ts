export enum ProcessingFeeMethod {
  RECOMMENDED = 'recommended',
  CUSTOM = 'custom',
  NONE = 'none',
}

export interface ProcessingFeeDetails {
  method: ProcessingFeeMethod;
  timeToConfirm: number;
}
