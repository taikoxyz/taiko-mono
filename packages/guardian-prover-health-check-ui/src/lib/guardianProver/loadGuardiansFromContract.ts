import { guardianProverABI } from '$abi';
import { GuardianProverStatus, type Guardian } from '$lib/types';
import { publicClient } from '$lib/wagmi/publicClient';
import type { Address } from 'viem';

const contractAddress = import.meta.env.VITE_GUARDIAN_PROVER_CONTRACT_ADDRESS;

export async function loadGuardiansFromContract(): Promise<Guardian[]> {
  const guardians: Guardian[] = [];

  const numGuardians = await publicClient.readContract({
    address: contractAddress,
    abi: guardianProverABI,
    functionName: 'numGuardians'
  });

  for (let i = 0; i < Number(numGuardians); i++) {
    const guardianAddress = await publicClient.readContract({
      address: contractAddress,
      abi: guardianProverABI,
      functionName: 'guardians',
      args: [i]
    });

    const guardianId = await publicClient.readContract({
      address: contractAddress,
      abi: guardianProverABI,
      functionName: 'guardianIds',
      args: [guardianAddress]
    });

    guardians.push({
      name: '',
      address: guardianAddress as Address,
      id: guardianId as number,
      latestHealthCheck: null,
      alive: GuardianProverStatus.DEAD
    });
  }
  return guardians;
}
