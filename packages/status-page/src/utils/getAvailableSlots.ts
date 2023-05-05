import type { ethers } from "ethers";
import { getConfig } from "./getConfig";
import { getStateVariables } from "./getStateVariables";

export const getAvailableSlots = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
): Promise<number> => {
  const stateVariables = await getStateVariables(provider, contractAddress);
  const config = await getConfig(provider, contractAddress);

  const nextBlockId = stateVariables.numBlocks;
  const latestVerifiedId = stateVariables.lastVerifiedBlockId;
  const pendingBlocks = nextBlockId - latestVerifiedId - 1;

  return Math.abs(pendingBlocks - config.maxNumProposedBlocks);
};
