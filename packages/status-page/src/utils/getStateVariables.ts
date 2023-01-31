import { BigNumber, Contract, ethers } from "ethers";
import TaikoL1 from "../constants/abi/TaikoL1";

export const getStateVariables = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
) => {
  const contract: Contract = new Contract(contractAddress, TaikoL1, provider);
  return await contract.getStateVariables();
};
