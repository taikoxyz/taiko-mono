import { guardianProverABI } from '$abi';
import { GuardianProverStatus, type Guardian } from '$lib/types';
import { publicClient } from '$lib/wagmi/publicClient';
import type { Address } from 'viem';

export async function loadGuardiansFromContract(): Promise<Guardian[]> {
	const guardians: Guardian[] = [];
	const contractAddress = import.meta.env.VITE_GUARDIAN_PROVER_CONTRACT_ADDRESS as Address;

	const numGuardians: number = await publicClient
		.readContract({
			address: contractAddress,
			abi: guardianProverABI,
			functionName: 'numGuardians'
		})
		.then(Number);

	if (numGuardians === 0) return guardians;

	const calls = [];
	for (let i = 0; i < numGuardians; i++) {
		calls.push(
			{ address: contractAddress, abi: guardianProverABI, functionName: 'guardians', args: [i] },
			{ address: contractAddress, abi: guardianProverABI, functionName: 'guardianIds', args: [i] }
		);
	}
	// @ts-expect-error: Suppress excessive deep type instantiation warning
	const results = await publicClient.multicall({
		contracts: calls
	});

	for (let i = 0; i < numGuardians; i++) {
		const guardianAddress = results[i * 2].result as Address;
		const guardianId = results[i * 2 + 1].result as number;

		guardians.push({
			name: '',
			address: guardianAddress,
			id: guardianId,
			latestHealthCheck: null,
			alive: GuardianProverStatus.DEAD
		});
	}

	return guardians;
}
