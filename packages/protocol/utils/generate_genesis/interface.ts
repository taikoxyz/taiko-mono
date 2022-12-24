export interface Config {
    contractOwner: string;
    chainId: number;
    seedAccounts: Array<{
        [key: string]: number;
    }>;
    predeployERC20: boolean;
    contractAddresses: Object;
}

export interface Result {
    alloc: any;
    storageLayouts: any;
}
