import { BigNumber, ethers } from "ethers";
import { getStateVariables } from "./getStateVariables";

export const getNextBlockId = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
): Promise<number> => {
  const stateVariables = await getStateVariables(provider, contractAddress);
  const nextBlockId = stateVariables.numBlocks;
  return BigNumber.from(nextBlockId).toNumber();
};
