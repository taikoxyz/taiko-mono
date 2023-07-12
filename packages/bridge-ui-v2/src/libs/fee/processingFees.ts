import { type ProcessingFeeDetails, ProcessingFeeMethod } from './types';

// Order is important, and the reason to use a Map
export const processingFees: Map<ProcessingFeeMethod, ProcessingFeeDetails> = new Map([
  [
    ProcessingFeeMethod.RECOMMENDED,
    {
      method: ProcessingFeeMethod.RECOMMENDED,
      timeToConfirm: 15 * 60 * 1000,
    },
  ],
  [
    ProcessingFeeMethod.NONE,
    {
      method: ProcessingFeeMethod.NONE,
      timeToConfirm: 15 * 60 * 1000,
    },
  ],
  [
    ProcessingFeeMethod.CUSTOM,
    {
      method: ProcessingFeeMethod.CUSTOM,
      timeToConfirm: 15 * 60 * 1000,
    },
  ],
]);
