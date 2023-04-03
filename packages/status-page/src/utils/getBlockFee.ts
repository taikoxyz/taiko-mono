import { BigNumber, Contract, ethers } from "ethers";
import TaikoL1 from "../constants/abi/TaikoL1";

export const getProverFee = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
): Promise<string> => {
  const contract: Contract = new Contract(contractAddress, TaikoL1, provider);
  const fee = await contract.getProverFee();
  return ethers.utils.formatEther(fee);
};
