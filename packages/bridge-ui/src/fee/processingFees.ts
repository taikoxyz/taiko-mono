import { type ProcessingFeeDetails, ProcessingFeeMethod } from '../domain/fee';

// Order is important, and the reason to use a Map
export const processingFees: Map<ProcessingFeeMethod, ProcessingFeeDetails> =
  new Map([
    [
      ProcessingFeeMethod.RECOMMENDED,
      {
        method: ProcessingFeeMethod.RECOMMENDED,
        displayText: 'Recommended',
        timeToConfirm: 15 * 60 * 1000,
      },
    ],
    [
      ProcessingFeeMethod.CUSTOM,
      {
        method: ProcessingFeeMethod.CUSTOM,
        displayText: 'Custom',
        timeToConfirm: 15 * 60 * 1000,
      },
    ],
    [
      ProcessingFeeMethod.NONE,
      {
        method: ProcessingFeeMethod.NONE,
        displayText: 'None',
        timeToConfirm: 15 * 60 * 1000,
      },
    ],
  ]);
