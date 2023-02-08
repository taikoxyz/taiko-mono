import { Contract, ethers } from "ethers";
import TaikoL1 from "../constants/abi/TaikoL1";

export const getAvailableSlots = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
): Promise<number> => {
  const contract: Contract = new Contract(contractAddress, TaikoL1, provider);
  const stateVariables = await contract.getStateVariables();
  const nextBlockId = stateVariables.nextBlockId;
  const latestVerifiedId = stateVariables.latestVerifiedId;
  const pendingBlocks = nextBlockId - latestVerifiedId - 1;
  return Math.abs(pendingBlocks - 2048);
};
