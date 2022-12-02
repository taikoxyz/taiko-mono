enum ProcessingFeeMethod {
  RECOMMENDED = "recommended",
  CUSTOM = "custom",
  NONE = "none",
};

interface ProcessingFeeDetails {
  DisplayText: string;
  TimeToConfirm: number;
};

const PROCESSING_FEE_META: Map<ProcessingFeeMethod, ProcessingFeeDetails> =  new Map([[ProcessingFeeMethod.RECOMMENDED, {
  DisplayText: "Recommended",
  TimeToConfirm: 15 * 60 * 1000,
}], [ProcessingFeeMethod.CUSTOM, {
  DisplayText: "Custom Amount",
  TimeToConfirm: 15 * 60 * 1000,
}], [ProcessingFeeMethod.NONE, {
  DisplayText: "No Fees",
  TimeToConfirm: 15 * 60 * 1000,
}]]);

export { ProcessingFeeDetails, ProcessingFeeMethod, PROCESSING_FEE_META };