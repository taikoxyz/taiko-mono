export enum BridgingStatus {
  PENDING,
  DONE,
}

export enum BridgeTypes {
  FUNGIBLE,
  NFT,
}

export enum BridgeSteps {
  IMPORT,
  REVIEW,
  RECIPIENT,
  CONFIRM,
}

export enum ImportMethod {
  NONE,
  MANUAL,
  SCAN,
}

export type BridgeType = BridgeTypes;
