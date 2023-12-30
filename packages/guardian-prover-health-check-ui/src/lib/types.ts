
export type SignedBlock = {
    blockHash: string;
    signature: string;
    guardianProverID: number;
};

export type SignedBlocks = { [key: string]: SignedBlock[] };

export type SortedSignedBlocks = Array<{ blockNumber: string, blocks: SignedBlock[] }>;

export type GuardianProverIdsMap = {
    [blockNumber: string]: number[];
}

export type HealthCheckMap = { [guardianProverId: number]: HealthCheck[] };


export type HealthCheck = {
    id: number;
    guardianProverId: number;
    alive: boolean;
    expectedAddress: string;
    recoveredAddress: string;
    signedResponse: string;
    createdAt: string;
};

export type Stat = {
    guardianProverId: number;
    date: string;
    requests: number;
    successfulRequests: number;
    uptime: number;
    createdAt: number;
};

export type PageResponse<T> = {
    items: T[];
    page: number;
    size: number;
    max_page: number;
    total_pages: number;
    total: number;
    last: boolean;
    first: boolean;
    visible: number;
};

export type Guardian = {
    address: string;
    id: number;
    latestHealthCheck: HealthCheck;
    alive: GuardianProverStatus;
    balance?: string;
};

export enum PageTabs {
    GUARDIAN_PROVER,
    BLOCKS
}


// enum that maps true and false to ALIVE and DEAD
export enum GuardianProverStatus {
    ALIVE = 1,
    DEAD = 0,
}