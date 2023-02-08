import { BigNumber, Contract, ethers } from "ethers";
import TaikoL1 from "../constants/abi/TaikoL1";

export const getLastVerifiedBlockId = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
): Promise<number> => {
  const contract: Contract = new Contract(contractAddress, TaikoL1, provider);
  const stateVariables = await contract.getStateVariables();
  const latestVerifiedId = stateVariables.latestVerifiedId;
  return BigNumber.from(latestVerifiedId).toNumber();
};
