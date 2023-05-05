import type { ethers } from "ethers";
import TaikoL1 from "../constants/abi/TaikoL1";
import { getStateVariables } from "./getStateVariables";

export const getPendingBlocks = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
): Promise<number> => {
  const stateVariables = await getStateVariables(provider, contractAddress);
  const nextBlockId = stateVariables.numBlocks;
  const lastBlockId = stateVariables.lastVerifiedBlockId;
  return nextBlockId - lastBlockId - 1;
};
