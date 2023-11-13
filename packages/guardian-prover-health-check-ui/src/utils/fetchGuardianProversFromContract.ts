import { ethers } from "ethers";
import guardianProverAbi from "../abi/guardianProver";
import type { HealthCheck } from "./fetchGuardianProverStats";

export type Guardian = {
  address: string;
  id: number;
  latestHealthCheck: HealthCheck;
  alive: boolean;
};

export async function fetchGuardianProversFromContract(
  contractAddress: string,
  provider: ethers.providers.Provider
): Promise<Guardian[]> {
  const contract = new ethers.Contract(
    contractAddress,
    guardianProverAbi,
    provider
  );

  const numGuardians = await contract.NUM_GUARDIANS();

  const guardians: Guardian[] = [];

  for (let i = 0; i < numGuardians; i++) {
    const guardianAddress = await contract.guardians(i);
    const guardianId = await contract.guardianIds(guardianAddress);

    guardians.push({
      address: guardianAddress,
      id: guardianId,
      latestHealthCheck: null,
      alive: true,
    });
  }

  return guardians;
}
