export interface Config {
    contractOwner: string;
    l1ChainId: number;
    chainId: number;
    seedAccounts: Array<{
        [key: string]: number;
    }>;
    predeployERC20: boolean;
    contractAddresses: Object;
    param1559: Object;
    pacayaForkHeight: number;
    shastaForkHeight: number;
    livenessBondGwei: number;
    provabilityBondGwei: number;
    withdrawalDelay: number;
    maxCheckpointStackSize: number;
    minBond: number;
    bondToken: string;
}

export interface Result {
    alloc: any;
    storageLayouts: any;
}
