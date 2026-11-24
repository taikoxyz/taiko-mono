// A new Etna network's EtnaStaking and bridged TAIKO predeploys (etna.ts); numbers are decimal
// strings.
export interface EtnaConfig {
    // The Etna Inbox proxy on L1.
    inbox: string;
    // The TAIKO token on L1, mapped in the L2 ERC20Vault to the bridged TAIKO predeploy.
    l1TaikoToken: string;
    // The EtnaStaking owner, the DAO's execution address on L2.
    stakingOwner: string;
    minStake: string;
    vpUnit: string;
    nMax: string;
    withdrawalDelay: string;
    // The Inbox's unsettledLimit and the double-sign evidence window, both in L2 blocks: only
    // checked against withdrawalDelay.
    unsettledLimit: string;
    evidenceWindowBlocks: string;
    slashBountyBps: string;
    slashSink: string;
    forfeitBps: string;
    // Must be true for a premint, and is refused on chains 167000, 167009 and 167013.
    devnet: boolean;
    // L2 TAIKO minted at genesis that no L1 TAIKO backs, as address-amount pairs.
    premint: Array<{
        [address: string]: string;
    }>;
}

export interface Config {
    contractOwner: string;
    l1ChainId: number;
    // Only with `etna`, whose L2 SignalService is the `EtnaSignalService`: its `usesBeaconRoots`.
    // False keeps checkpoints as its only root source; a new Etna network uses true.
    usesBeaconRoots?: boolean;
    chainId: number;
    seedAccounts: Array<{
        [key: string]: number;
    }>;
    predeployERC20: boolean;
    contractAddresses: Object;
    param1559: Object;
    remoteSignalService: string;
    etna?: EtnaConfig;
}

export interface Result {
    alloc: any;
    storageLayouts: any;
}
