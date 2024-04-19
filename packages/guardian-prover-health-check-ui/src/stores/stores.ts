import {
	type Guardian,
	type HealthCheck,
	type SortedSignedBlocks,
	type GuardianProverIdsMap,
	PageTabs
} from '$lib/types';
import { type Writable, writable, derived } from 'svelte/store';

// Healtchecks
export const apiResponse: Writable<HealthCheck[]> = writable([]);
export const lastGuardianFetchTimestamp: Writable<number> = writable(Date.now());

// Guardian provers
export const guardianProvers: Writable<Guardian[]> = writable(null);
export const minGuardianRequirement: Writable<number> = writable(null);
export const totalGuardianProvers: Writable<number> = writable(null);

// Signed blocks
export const signedBlocks: Writable<SortedSignedBlocks> = writable([]);
export const signerPerBlock: Writable<GuardianProverIdsMap> = writable({});

// Page state
export const loading: Writable<boolean> = writable(false);
export const selectedTab = writable<PageTabs>(PageTabs.GUARDIAN_PROVER);
export const selectedGuardianProver = writable<Guardian>();

interface StatusCounts {
	dead: number;
	alive: number;
	unhealthy: number;
}

export const guardianStatusCounts = derived(guardianProvers, ($guardianProvers): StatusCounts => {
	if (!$guardianProvers) return { dead: 0, alive: 0, unhealthy: 0 };

	return $guardianProvers.reduce(
		(acc, guardian) => {
			switch (guardian.alive) {
				case 0: // DEAD
					acc.dead += 1;
					break;
				case 1: // ALIVE
					acc.alive += 1;
					break;
				case 2: // UNHEALTHY
					acc.unhealthy += 1;
					break;
			}
			return acc;
		},
		{ dead: 0, alive: 0, unhealthy: 0 }
	);
});
