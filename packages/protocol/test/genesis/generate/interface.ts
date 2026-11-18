export interface Config {
    contractOwner: string;
    l1ChainId: number;
    // The L2 SignalService's `beaconRootsFrom`, as a 0x-prefixed hex string: 0x0 keeps checkpoints
    // as its only root source; a new Etna network uses max(1, genesis timestamp).
    beaconRootsFrom: string;
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
