import { BigNumber, Contract, ethers } from "ethers";
import TaikoL1 from "../constants/abi/TaikoL1";
import { truncateString } from "./truncateString";

export const getProofReward = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
): Promise<string> => {
  const contract: Contract = new Contract(contractAddress, TaikoL1, provider);
  const state = await contract.getStateVariables();
  const fee = await contract.getProofReward(
    new Date().getMilliseconds(),
    state.lastProposedAt
  );
  return truncateString(ethers.utils.formatEther(fee), 8);
};
