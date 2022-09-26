export interface Config {
    contractOwner: string
    ethDepositor: string
    chainId: number
    premintEthAccounts: Array<{
        [key: string]: number
    }>
    predeployERC20: boolean
}

export interface Result {
    alloc: any
    storageLayouts: any
}
