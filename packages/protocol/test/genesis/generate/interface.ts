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
    livenessBond: string | number;
    withdrawalDelay: number;
    minBond: number;
    bondToken: string;
    remoteSignalService: string;
    pacayaTaikoAnchor: string;
}

export interface Result {
    alloc: any;
    storageLayouts: any;
}
