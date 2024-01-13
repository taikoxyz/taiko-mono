import { guardianProverABI } from '$abi';
import { publicClient } from '$lib/wagmi/publicClient';

const contractAddress = import.meta.env.VITE_GUARDIAN_PROVER_CONTRACT_ADDRESS;

export async function fetchGuardianProverRequirementsFromContract(): Promise<number> {
	const minRequirement = await publicClient.readContract({
		address: contractAddress,
		abi: guardianProverABI,
		functionName: 'minGuardians'
	});

	return minRequirement as number;
}
