import { writable } from 'svelte/store';
import { ProcessingFeeMethod } from '../domain/fee';

export const processingFee = writable<ProcessingFeeMethod>(
  ProcessingFeeMethod.RECOMMENDED,
);
