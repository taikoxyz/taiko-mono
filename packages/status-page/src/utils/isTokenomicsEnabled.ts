import { Contract, ethers } from "ethers";
import TaikoL1 from "../constants/abi/TaikoL1";

export const isTokenomicsEnabled = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
): Promise<boolean> => {
  const contract: Contract = new Contract(contractAddress, TaikoL1, provider);
  const enableTokenomics = await contract.getConfig();
  return enableTokenomics;
};
