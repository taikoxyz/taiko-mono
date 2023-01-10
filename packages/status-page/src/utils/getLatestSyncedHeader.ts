import { Contract, ethers } from "ethers";
import TaikoL1 from "../constants/abi/TaikoL1";

export const getLatestSyncedHeader = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
): Promise<string> => {
  const contract: Contract = new Contract(contractAddress, TaikoL1, provider);
  const header = await contract.getLatestSyncedHeader();
  return header;
};
