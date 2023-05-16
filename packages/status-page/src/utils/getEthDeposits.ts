import type { ethers } from "ethers";
import { getStateVariables } from "./getStateVariables";

export const getEthDeposits = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
): Promise<number> => {
  const stateVariables = await getStateVariables(provider, contractAddress);
  return stateVariables.numEthDeposits.toNumber();
};
