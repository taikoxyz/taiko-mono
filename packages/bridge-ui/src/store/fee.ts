import { derived, writable } from "svelte/store";
import { ethers } from 'ethers';

import { ProcessingFeeOpts } from "../domain/fee";

export const processingFee = writable<ProcessingFeeOpts>(ProcessingFeeOpts.RECOMMENDED);

export const processingFeeDetails = writable<Map<ProcessingFeeOpts, ProcessingFeeDetails>>(
  new Map([[ProcessingFeeOpts.RECOMMENDED, {
    displayText: "Recommended",
    value: ethers.utils.parseEther("0.001"),
    timeToConfirm: 15 * 60 * 1000,
  }], [ProcessingFeeOpts.CUSTOM, {
    displayText: "Custom Amount",
    value: ethers.utils.parseEther("0.001"),
    timeToConfirm: 15 * 60 * 1000,
  }], [ProcessingFeeOpts.NONE, {
    displayText: "No Fees",
    value: ethers.utils.parseEther("0.001"),
    timeToConfirm: 15 * 60 * 1000,
  }]]
  )
);

export const currentSelectedProcessingFee = derived([processingFee, processingFeeDetails], ($values) =>
  $values[1].get($values[0])
);
