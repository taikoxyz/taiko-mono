enum ProcessingFeeMethod {
  RECOMMENDED = "recommended",
  CUSTOM = "custom",
  NONE = "none",
}

interface ProcessingFeeDetails {
  displayText: string;
  timeToConfirm: number;
}

const PROCESSING_FEE_META: Map<ProcessingFeeMethod, ProcessingFeeDetails> =
  new Map([
    [
      ProcessingFeeMethod.RECOMMENDED,
      {
        displayText: "Recommended",
        timeToConfirm: 15 * 60 * 1000,
      },
    ],
    [
      ProcessingFeeMethod.CUSTOM,
      {
        displayText: "Custom",
        timeToConfirm: 15 * 60 * 1000,
      },
    ],
    [
      ProcessingFeeMethod.NONE,
      {
        displayText: "None",
        timeToConfirm: 15 * 60 * 1000,
      },
    ],
  ]);

export { ProcessingFeeDetails, ProcessingFeeMethod, PROCESSING_FEE_META };
