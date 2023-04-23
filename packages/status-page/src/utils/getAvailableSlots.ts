import { Contract, ethers } from "ethers";
import TaikoL1 from "../constants/abi/TaikoL1";
import { getConfig } from "./getConfig";

export const getAvailableSlots = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
): Promise<number> => {
  const contract: Contract = new Contract(contractAddress, TaikoL1, provider);
  const stateVariables = await contract.getStateVariables();
  const config = await getConfig(provider, contractAddress);

  const nextBlockId = stateVariables.nextBlockId;
  const latestVerifiedId = stateVariables.latestVerifiedId;
  const pendingBlocks = nextBlockId - latestVerifiedId - 1;
  return Math.abs(pendingBlocks - config.maxNumBlocks);
};
