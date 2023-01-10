import { Contract, ethers } from "ethers";
import TaikoL1 from "../constants/abi/TaikoL1";

export const getBlockFee = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
): Promise<number> => {
  const contract: Contract = new Contract(contractAddress, TaikoL1, provider);
  const fee = await contract.getBlockFee();
  return fee;
};
