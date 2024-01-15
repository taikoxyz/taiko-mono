import { fetchGuardianProversFromContract } from './guardianProver/fetchGuardianProversFromContract';
import { GuardianProverStatus, type SignedBlocks } from './types';
import { fetchSignedBlocksFromApi } from './api/signedBlocksApiCalls';
import { getGuardianProverIdsPerBlockNumber } from './blocks/getGuardianProverIdsPerBlockNumber';
import { sortSignedBlocksDescending } from './blocks/sortSignedBlocks';
import { publicClient } from './wagmi/publicClient';
import { formatEther, type Address } from 'viem';
import { fetchLatestGuardianProverHealtCheckFromApi, fetchUptimeFromApi } from './api';
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

const BLOCKS_TO_CHECK = 20;
const THRESHOLD = BLOCKS_TO_CHECK / 2;
const HEALTHCHECK_TIMEOUT_IN_SECONDS = 60;

export function startFetching() {
	// Fetch all data immediately
	refreshData();

	// Set up an interval to fetch guardians every 30 seconds
	const guardiansInterval = setInterval(() => {
		fetchGuardians();
	}, 30000);

	// Set up an interval to fetch signed block and liveliness stats every 12 seconds
	const blocksAndLivelinessInterval = setInterval(() => {
		fetchSignedBlockStats();
		determineLiveliness();
	}, 12000);

	// Return a function to clear all intervals
	return () => {
		clearInterval(guardiansInterval);
		clearInterval(blocksAndLivelinessInterval);
	};
}

export async function refreshData() {
	loading.set(true);
	await fetchSignedBlockStats();
	await fetchGuardians();
	await determineLiveliness();
	loading.set(false);
}

async function fetchGuardians() {
	const rawData = await fetchGuardianProversFromContract();
	const required = await fetchGuardianProverRequirementsFromContract();

	minGuardianRequirement.set(required);
	totalGuardianProvers.set(rawData.length);

	const guardians = [];
	for (const guardian of rawData) {
		const balance = await publicClient.getBalance({
			address: guardian.address as Address
		});

		const balanceAsEther = formatEther(balance);
		guardian.balance = balanceAsEther;

		const status = await fetchLatestGuardianProverHealtCheckFromApi(
			import.meta.env.VITE_GUARDIAN_PROVER_API_URL,
			guardian.id
		);
		guardian.latestHealthCheck = status;

		const uptime = await fetchUptimeFromApi(
			import.meta.env.VITE_GUARDIAN_PROVER_API_URL,
			guardian.id
		);
		guardian.uptime = uptime;
		if (uptime > 100) guardian.uptime = 100;

		guardian.alive = status.alive ? GuardianProverStatus.ALIVE : GuardianProverStatus.DEAD;

		guardians.push(guardian);
	}

	lastGuardianFetchTimestamp.set(Date.now());

	guardianProvers.set(guardians);
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

	const guardians = get(guardianProvers);
	if (!guardians) return;
	for (const guardian of guardians) {
		const latestCheck = guardian.latestHealthCheck;
		const createdAt = new Date(latestCheck.createdAt);
		const secondsSinceLastCheck = (now.getTime() - createdAt.getTime()) / 1000;

		if (secondsSinceLastCheck > HEALTHCHECK_TIMEOUT_IN_SECONDS) {
			guardian.alive = GuardianProverStatus.DEAD;
			break;
		}
		let countSignedBlocks = 0;
		const recentSignedBlocks = get(signedBlocks).slice(0, BLOCKS_TO_CHECK);

		for (const block of recentSignedBlocks) {
			if (block.blocks.some((b) => b.guardianProverID === Number(guardian.id))) {
				countSignedBlocks++;
			}
		}

		// Update status based on whether the guardian signed at least half of the configured blocks to check
		guardian.alive =
			countSignedBlocks >= THRESHOLD ? GuardianProverStatus.ALIVE : GuardianProverStatus.UNHEALTHY;
	}
}
