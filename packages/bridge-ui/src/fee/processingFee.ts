import { ProcessingFeeDetails, ProcessingFeeMethod } from '../domain/fee';

export const processingFeeMap: Map<ProcessingFeeMethod, ProcessingFeeDetails> =
  new Map([
    [
      ProcessingFeeMethod.RECOMMENDED,
      {
        displayText: 'Recommended',
        timeToConfirm: 15 * 60 * 1000,
      },
    ],
    [
      ProcessingFeeMethod.CUSTOM,
      {
        displayText: 'Custom',
        timeToConfirm: 15 * 60 * 1000,
      },
    ],
    [
      ProcessingFeeMethod.NONE,
      {
        displayText: 'None',
        timeToConfirm: 15 * 60 * 1000,
      },
    ],
  ]);
