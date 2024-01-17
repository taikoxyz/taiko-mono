export enum BridgeTypes {
  FUNGIBLE = 'FUNGIBLE',
  NFT = 'NFT',
}

export enum NFTSteps {
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
