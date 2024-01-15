import {
	type Guardian,
	type HealthCheck,
	type SortedSignedBlocks,
	type GuardianProverIdsMap,
	PageTabs
} from '$lib/types';
import { type Writable, writable } from 'svelte/store';

// Healtchecks
export const apiResponse: Writable<HealthCheck[]> = writable([]);
export const lastGuardianFetchTimestamp: Writable<number> = writable(0);

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
