enum ProcessingFeeOpts {
  RECOMMENDED = "recommended",
  CUSTOM = "custom",
  NONE = "none",
}

type ProcessingFeeDetails = {
  displayText: string;
  value: number;
  timeToConfirm: number;
}

export { ProcessingFeeDetails, ProcessingFeeOpts };