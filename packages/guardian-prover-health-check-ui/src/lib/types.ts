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
	uptime?: number;
};

export enum PageTabs {
	GUARDIAN_PROVER,
	BLOCKS
}

export enum GuardianProverStatus {
	DEAD,
	ALIVE,
	UNHEALTHY
}

export enum GlobalHealth {
	HEALTHY,
	WARNING,
	CRITICAL
}
