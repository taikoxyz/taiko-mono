export interface Config {
    contractOwner: string;
    l1ChainId: number;
    // The L2 SignalService's `usesBeaconRoots`: false keeps checkpoints as its only root source;
    // a new Etna network uses true.
    usesBeaconRoots: boolean;
    chainId: number;
    seedAccounts: Array<{
        [key: string]: number;
    }>;
    predeployERC20: boolean;
    contractAddresses: Object;
    param1559: Object;
    remoteSignalService: string;
}

export interface Result {
    alloc: any;
    storageLayouts: any;
}
