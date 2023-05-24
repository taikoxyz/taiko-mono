import { BigNumber, ethers } from "ethers";
import { getStateVariables } from "./getStateVariables";

export const getLastVerifiedBlockId = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
): Promise<number> => {
  const stateVariables = await getStateVariables(provider, contractAddress);
  const lastBlockId = stateVariables.lastVerifiedBlockId;
  return BigNumber.from(lastBlockId).toNumber();
};
