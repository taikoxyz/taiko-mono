export type SignedBlock = {
	blockHash: string;
	signature: string;
	guardianProverID: number;
};

export type SignedBlocks = { [key: string]: SignedBlock[] };

export type SortedSignedBlocks = Array<{ blockNumber: string; blocks: SignedBlock[] }>;

export type GuardianProverIdsMap = {
	[blockNumber: string]: number[];
};

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

export type UptimeResponse = {
	uptime: number;
	numHealthChecksLast24Hours: number;
};

export type StartupResponse = {
	guardianProverID: number;
	guardianProverAddress: string;
	revision: string;
	version: string;
	createdAt: string;
};

export type NodeInfoResponse = {
	guardianProverID: number;
	guardianProverAddress: string;
	l1NodeVersion: string;
	l2NodeVersion: string;
	revision: string;
	guardianVersion: string;
	createdAt: string;
	latestL1BlockNumber: number;
	latestL2BlockNumber: number;
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
	name: string;
	address: string;
	id: number;
	latestHealthCheck: HealthCheck;
	alive: GuardianProverStatus;
	balance?: string;
	lastRestart?: string;
	uptime?: number;
	versionInfo?: VersionInfo;
	blockInfo?: BlockInfo;
};

export type BlockInfo = {
	latestL1BlockNumber: number;
	latestL2BlockNumber: number;
};

export type VersionInfo = {
	guardianProverAddress: string;
	guardianProverID: number;
	guardianVersion: string;
	l1NodeVersion: string;
	l2NodeVersion: string;
	revision: string;
};

export enum PageTabs {
	GUARDIAN_PROVER,
	BLOCKS
}

export enum GuardianProverStatus {
	DEAD,
	ALIVE,
	UNHEALTHY,
	UNKNOWN
}

export enum GlobalHealth {
	HEALTHY,
	WARNING,
	CRITICAL
}
