export interface Config {
    contractOwner: string;
    l1ChainId: number;
    // First L2 block timestamp at which the Etna fork is active, as a 0x-prefixed hex string.
    etnaTimestamp: string;
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
