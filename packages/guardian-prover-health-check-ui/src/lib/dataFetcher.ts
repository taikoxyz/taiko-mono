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
import { loadGuardiansFromContract } from './guardianProver/loadGuardiansFromContract';
import { getLogger } from './util/logger';

const log = getLogger('dataFetcher');

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

	log('refreshData start');

	if (!get(guardianProvers) || get(guardianProvers).length === 0) {
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
	log('refreshData end');
}

async function initializeGuardians(): Promise<void> {
	log('initializeGuardians start');
	const startTime = Date.now();

	try {
		log('Loading contract guardians start');
		const contractGuardians = await loadGuardiansFromContract();
		log('Loading contract guardians end', Date.now() - startTime);

		log('Loading pseudonym mapping start');
		const guardianPseudonymMapping = await loadGuardians();
		log('Loading pseudonym mapping end', Date.now() - startTime);

		const rawGuardians: Guardian[] = contractGuardians.map((guardian) => {
			const name = guardianPseudonymMapping[guardian.address] || guardian.address;
			return {
				...guardian,
				name,
				balance: null,
				lastRestart: null,
				uptime: null,
				versionInfo: null,
				blockInfo: null,
				latestHealthCheck: guardian.latestHealthCheck, // Preserve initial state
				alive: guardian.alive // Preserve initial state
			};
		});

		// Batch update guardianProvers store
		guardianProvers.update(() => rawGuardians);
	} catch (error) {
		log('Error initializing guardians:', error);
		throw error;
	}

	log('initializeGuardians end', Date.now() - startTime);
}

async function fetchGuardians() {
	log('fetchGuardians start');
	const existingGuardians = get(guardianProvers) || [];

	try {
		const [required] = await Promise.all([fetchGuardianProverRequirementsFromContract()]);

		minGuardianRequirement.set(required);
		totalGuardianProvers.set(existingGuardians.length);

		const guardianFetchPromises = existingGuardians.map(async (newGuardian) => {
			const guardian = existingGuardians.find((g) => g.address === newGuardian.address) || {
				...newGuardian,
				alive: GuardianProverStatus.UNKNOWN
			};

			guardian.name = await getPseudonym(guardian.address);
			if (!guardian.name) {
				guardian.name = guardian.address;
			}

			const [status, uptime, balance] = await Promise.all([
				fetchLatestGuardianProverHealthCheckFromApi(
					import.meta.env.VITE_GUARDIAN_PROVER_API_URL,
					guardian.address
				),
				fetchUptimeFromApi(import.meta.env.VITE_GUARDIAN_PROVER_API_URL, guardian.address),
				publicClient.getBalance({ address: guardian.address as Address })
			]);

			guardian.balance = formatEther(balance);
			log('balance', guardian.name, guardian.balance);

			guardian.latestHealthCheck = status;
			guardian.uptime = Math.min(uptime, 100);

			return guardian;
		});

		const updatedGuardians = await Promise.all(guardianFetchPromises);
		guardianProvers.set(updatedGuardians);
		lastGuardianFetchTimestamp.set(Date.now());
		log('updatedGuardians', updatedGuardians);
	} catch (error) {
		log('Error fetching guardians:', error);
		throw error;
	}

	log('fetchGuardians end');
}

async function fetchSignedBlockStats() {
	log('fetchSignedBlockStats start');
	const blocks: SignedBlocks = await fetchSignedBlocksFromApi(
		import.meta.env.VITE_GUARDIAN_PROVER_API_URL
	);

	signedBlocks.set(sortSignedBlocksDescending(blocks));

	const signer = await getGuardianProverIdsPerBlockNumber(blocks);
	signerPerBlock.set(signer);
	log('fetchSignedBlockStats end');
}

async function determineLiveliness(): Promise<void> {
	log('determineLiveliness start');
	const now = new Date();
	guardianProvers.update((guardians) =>
		guardians.map((guardian) => {
			const latestCheck = guardian.latestHealthCheck;
			const createdAt = new Date(latestCheck?.createdAt || 0);
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
	log('determineLiveliness end');
}

async function fetchStats(): Promise<void> {
	log('fetchStats start');
	const guardians = get(guardianProvers);

	const updatedGuardiansPromises = guardians.map(async (guardian) => {
		const startupDataFetch = fetchStartupDataFromApi(
			import.meta.env.VITE_GUARDIAN_PROVER_API_URL,
			guardian.address
		);

		const nodeInfoFetch = fetchNodeInfoFromApi(
			import.meta.env.VITE_GUARDIAN_PROVER_API_URL,
			guardian.address
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
	log('fetchStats end');
}
