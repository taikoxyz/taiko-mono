import {
	GuardianProverStatus,
	type BlockInfo,
	type Guardian,
	type SignedBlocks,
	type VersionInfo
} from './types';
import { fetchSignedBlocksFromApi } from './api/signedBlocksApiCalls';
import { getGuardianProverIdsPerBlockNumber } from './blocks/getGuardianProverIdsPerBlockNumber';
import { sortSignedBlocksDescending } from './blocks/sortSignedBlocks';
import { publicClient } from './wagmi/publicClient';
import { formatEther, type Address } from 'viem';
import {
	fetchLatestGuardianProverHealthCheckFromApi,
	fetchNodeInfoFromApi,
	fetchStartupDataFromApi,
	fetchUptimeFromApi
} from './api';
import { fetchGuardianProverRequirementsFromContract } from './guardianProver/fetchGuardianProverRequirementsFromContract';
import {
	minGuardianRequirement,
	lastGuardianFetchTimestamp,
	guardianProvers,
	signedBlocks,
	signerPerBlock,
	loading,
	totalGuardianProvers
} from '$stores';
import { get } from 'svelte/store';
import { getPseudonym } from './guardianProver/addressToPseudonym';
import { loadGuardians } from './guardianProver/loadConfiguredGuardians';

const BLOCKS_TO_CHECK = 20;
const THRESHOLD = BLOCKS_TO_CHECK / 2;
const HEALTHCHECK_TIMEOUT_IN_SECONDS = 60;

let guardiansIntervalId;
let blocksAndLivelinessIntervalId;

export async function startFetching() {
	await refreshData();

	loading.set(false);

	guardiansIntervalId = setInterval(fetchGuardians, 10000);
	blocksAndLivelinessIntervalId = setInterval(async () => {
		await Promise.all([fetchSignedBlockStats(), determineLiveliness()]);
	}, 12000);
}

export function stopFetching() {
	if (guardiansIntervalId) {
		clearInterval(guardiansIntervalId);
		guardiansIntervalId = null;
	}
	if (blocksAndLivelinessIntervalId) {
		clearInterval(blocksAndLivelinessIntervalId);
		blocksAndLivelinessIntervalId = null;
	}
}

export async function refreshData() {
	if (get(loading) === true) return;
	loading.set(true);

	if (!get(guardianProvers)) {
		// Initial data fetch
		await initializeGuardians();
		await fetchGuardians();
		await fetchSignedBlockStats();

		await Promise.all([determineLiveliness(), fetchStats()]);
	} else {
		// Subsequent data refresh
		await fetchGuardians();
		const block = fetchSignedBlockStats();
		const liveness = determineLiveliness();
		const stats = fetchStats();
		await Promise.all([block, stats, liveness]);
	}

	loading.set(false);
}

async function initializeGuardians() {
	const guardiansMap = await loadGuardians();
	const rawGuardians: Guardian[] = Object.entries(guardiansMap).map(([address, name], index) => ({
		name: name,
		address: address,
		id: index + 1, // add +1 as guardian contract numbers starts at 1
		latestHealthCheck: null,
		alive: GuardianProverStatus.UNKNOWN,
		balance: null,
		lastRestart: null,
		uptime: null,
		nodeInfo: null
	}));

	guardianProvers.set(rawGuardians);
}

async function fetchGuardians() {
	const existingGuardians = get(guardianProvers);

	const [required] = await Promise.all([fetchGuardianProverRequirementsFromContract()]);

	minGuardianRequirement.set(required);
	totalGuardianProvers.set(existingGuardians?.length);

	const guardianFetchPromises = existingGuardians.map(async (newGuardian) => {
		const guardian = existingGuardians.find((g) => g.id === newGuardian.id) || {
			...newGuardian,
			latestHealthCheck: null,
			uptime: 0,
			balance: '0',
			alive: GuardianProverStatus.UNKNOWN
		};

		guardian.name = await getPseudonym(guardian.address);

		const [status, uptime, balance] = await Promise.all([
			fetchLatestGuardianProverHealthCheckFromApi(
				import.meta.env.VITE_GUARDIAN_PROVER_API_URL,
				guardian.id
			),
			fetchUptimeFromApi(import.meta.env.VITE_GUARDIAN_PROVER_API_URL, guardian.id),
			publicClient.getBalance({ address: guardian.address as Address })
		]);
		guardian.balance = formatEther(balance);

		guardian.latestHealthCheck = status;
		guardian.uptime = Math.min(uptime, 100);

		return guardian;
	});

	const updatedGuardians = await Promise.all(guardianFetchPromises);
	guardianProvers.set(updatedGuardians);
	lastGuardianFetchTimestamp.set(Date.now());
}

async function fetchSignedBlockStats() {
	const blocks: SignedBlocks = await fetchSignedBlocksFromApi(
		import.meta.env.VITE_GUARDIAN_PROVER_API_URL
	);

	signedBlocks.set(sortSignedBlocksDescending(blocks));

	const signer = await getGuardianProverIdsPerBlockNumber(blocks);
	signerPerBlock.set(signer);
}

async function determineLiveliness(): Promise<void> {
	const now = new Date();
	guardianProvers.update((guardians) =>
		guardians.map((guardian) => {
			const latestCheck = guardian.latestHealthCheck;
			const createdAt = new Date(latestCheck.createdAt);
			const secondsSinceLastCheck = (now.getTime() - createdAt.getTime()) / 1000;
			let aliveStatus = guardian.alive;

			if (secondsSinceLastCheck > HEALTHCHECK_TIMEOUT_IN_SECONDS) {
				aliveStatus = GuardianProverStatus.DEAD;
			} else {
				let countSignedBlocks = 0;
				const recentSignedBlocks = get(signedBlocks).slice(0, BLOCKS_TO_CHECK);
				for (const block of recentSignedBlocks) {
					if (block.blocks.some((b) => b.guardianProverID === Number(guardian.id))) {
						countSignedBlocks++;
					}
				}
				aliveStatus =
					countSignedBlocks >= THRESHOLD
						? GuardianProverStatus.ALIVE
						: GuardianProverStatus.UNHEALTHY;
			}

			return { ...guardian, alive: aliveStatus };
		})
	);
}
async function fetchStats(): Promise<void> {
	const guardians = get(guardianProvers);

	const updatedGuardiansPromises = guardians.map(async (guardian) => {
		const startupDataFetch = fetchStartupDataFromApi(
			import.meta.env.VITE_GUARDIAN_PROVER_API_URL,
			guardian.id
		);

		const nodeInfoFetch = fetchNodeInfoFromApi(
			import.meta.env.VITE_GUARDIAN_PROVER_API_URL,
			guardian.id
		);

		const [startupData, nodeInfo] = await Promise.all([startupDataFetch, nodeInfoFetch]);

		const versions: VersionInfo = {
			guardianProverAddress: startupData.guardianProverAddress,
			guardianProverID: startupData.guardianProverID,
			guardianVersion: nodeInfo.guardianVersion,
			l1NodeVersion: nodeInfo.l1NodeVersion,
			l2NodeVersion: nodeInfo.l2NodeVersion,
			revision: startupData.revision
		};

		console.log('versions', versions);

		const blockInfo: BlockInfo = {
			latestL1BlockNumber: nodeInfo.latestL1BlockNumber,
			latestL2BlockNumber: nodeInfo.latestL2BlockNumber
		};

		return {
			...guardian,
			id: versions.guardianProverID,
			versionInfo: versions,
			lastRestart: startupData.createdAt,
			blockInfo: blockInfo
		};
	});

	const updatedGuardians = await Promise.all(updatedGuardiansPromises);
	guardianProvers.set(updatedGuardians);
}
