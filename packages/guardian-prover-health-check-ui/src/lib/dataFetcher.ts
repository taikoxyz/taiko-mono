import { writable } from 'svelte/store';
import type { Writable } from 'svelte/store';
import { fetchGuardianProversFromContract } from './guardianProver/fetchGuardianProversFromContract';
import { GuardianProverStatus, type Guardian, type GuardianProverIdsMap, type HealthCheck, type SignedBlocks, type SortedSignedBlocks } from './types';
import { fetchSignedBlocksFromApi } from './blocks/fetchSignedBlocksFromApi';
import { getGuardianProverIdsPerBlockNumber } from './blocks/getGuardianProverIdsPerBlockNumber';
import { sortSignedBlocksDescending } from './blocks/sortSignedBlocks';
import { publicClient } from './wagmi/publicClient';
import { formatEther, type Address } from 'viem';
import { fetchLatestGuardianProverRequest } from './guardianProver/fetchLatestGuardianProverRequest';

export const guardianProvers: Writable<Guardian[]> = writable([]);
export const apiResponse: Writable<HealthCheck[]> = writable([]);
export const signedBlocks: Writable<SortedSignedBlocks> = writable([]);
export const signerPerBlock: Writable<GuardianProverIdsMap> = writable({});

export const lastGuardianFetchTimestamp: Writable<number> = writable(0);

export async function fetchGuardians() {
    const guardians = await fetchGuardianProversFromContract();
    const guardiansWithBalance = [];
    for (const guardian of guardians) {
        const balance = await publicClient.getBalance({
            address: guardian.address as Address
        })

        const balanceAsEther = formatEther(balance)
        guardian.balance = balanceAsEther;

        const status = await fetchLatestGuardianProverRequest(import.meta.env.VITE_GUARDIAN_PROVER_API_URL, guardian.id);
        guardian.latestHealthCheck = status;

        // if status.createdAt is older than 60 seconds, set guardian to dead
        const createdAt = new Date(status.createdAt)
        const now = new Date()
        const diff = now.getTime() - createdAt.getTime()
        const seconds = diff / 1000
        if (seconds > 60) {
            guardian.alive = GuardianProverStatus.DEAD
        } else {
            guardian.alive = status.alive ? GuardianProverStatus.ALIVE : GuardianProverStatus.DEAD
        }
        guardiansWithBalance.push(guardian)
    }

    lastGuardianFetchTimestamp.set(Date.now());

    guardianProvers.set(guardiansWithBalance);
}


async function fetchSignedBlockStats() {
    const blocks: SignedBlocks = await fetchSignedBlocksFromApi(import.meta.env.VITE_GUARDIAN_PROVER_API_URL);

    signedBlocks.set(sortSignedBlocksDescending(blocks));

    const signer = await getGuardianProverIdsPerBlockNumber(blocks);
    signerPerBlock.set(signer);
}


export function startFetching() {
    // Fetch all data immediately
    fetchGuardians();
    fetchSignedBlockStats();

    // Set up an interval to fetch guardians every 30 seconds
    const guardiansInterval = setInterval(() => {
        fetchGuardians();
    }, 30000);

    // Set up an interval to fetch signed block stats every 12 seconds
    const blocksInterval = setInterval(() => {
        fetchSignedBlockStats();

    }, 12000);

    // Return a function to clear both intervals
    return () => {
        clearInterval(guardiansInterval);
        clearInterval(blocksInterval);
    };
}