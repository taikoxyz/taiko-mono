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
}

export interface Result {
    alloc: any;
    storageLayouts: any;
}
